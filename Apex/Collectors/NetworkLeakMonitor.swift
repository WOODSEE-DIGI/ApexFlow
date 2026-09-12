import Foundation
import Network
import AppKit
import Darwin

// MARK: - Network Leak Monitor

/// A lightweight, user-friendly "Little Snitch lite" that polls active outbound
/// TCP connections and raises alerts when background processes contact the WAN.
///
/// This is intentionally simpler than a packet filter: it does not block traffic,
/// it observes it. A true block/allow firewall would require a Network Extension
/// system extension, which is the next architectural step if blocking is needed.
actor NetworkLeakMonitor {
    private var previousConnections: Set<String> = []
    private var isRunning = false
    private var hostnameCache: [String: String?] = [:]

    func start(reportingTo data: NetworkLeakData) {
        guard !isRunning else { return }
        isRunning = true

        Task { [weak self] in
            while await self?.isRunning == true, !Task.isCancelled {
                await self?.scanOnce(data: data)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        isRunning = false
    }

    // MARK: - Scanning

    private func scanOnce(data: NetworkLeakData) async {
        let connections = establishedConnections()
        let newKeys = connections.subtracting(previousConnections)
        defer { previousConnections = connections }

        #if DEBUG
        print("[WAN] scan found \(connections.count) established connections, \(newKeys.count) new")
        #endif

        guard await data.isEnabled else { return }

        for key in newKeys {
            guard let conn = parseConnectionKey(key) else {
                #if DEBUG
                print("[WAN] failed to parse: \(key)")
                #endif
                continue
            }
            #if DEBUG
            print("[WAN] candidate: \(conn.command) \(conn.remoteAddress):\(conn.remotePort)")
            #endif
            guard !isPrivateAddress(conn.remoteAddress) else {
                #if DEBUG
                print("[WAN] ignored private remote: \(conn.remoteAddress)")
                #endif
                continue
            }

            let alert = buildAlert(conn)
            guard await !data.isApproved(alert) else {
                #if DEBUG
                print("[WAN] approved/ignored: \(conn.command)")
                #endif
                continue
            }

            await MainActor.run { data.add(alert) }
            #if DEBUG
            print("[WAN] alert added: \(conn.command) -> \(conn.remoteAddress):\(conn.remotePort)")
            #endif

            // Resolve the remote hostname in the background so the UI updates
            // when the PTR record comes back.
            Task {
                let hostname = await resolveHostname(for: conn.remoteAddress)
                await MainActor.run {
                    data.setResolvedHostname(id: alert.id, hostname: hostname)
                }
            }
        }
    }

    /// Reverse DNS lookup for an IP address, cached to avoid hammering the resolver.
    private func resolveHostname(for address: String) async -> String? {
        if let cached = hostnameCache[address] { return cached }

        let result = await Task.detached(priority: .utility) { () -> String? in
            var hints = addrinfo()
            hints.ai_flags = AI_NUMERICHOST
            hints.ai_family = AF_UNSPEC
            hints.ai_socktype = SOCK_STREAM

            var info: UnsafeMutablePointer<addrinfo>?
            guard getaddrinfo(address, nil, &hints, &info) == 0 else { return nil }
            defer { freeaddrinfo(info) }

            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard let addr = info?.pointee.ai_addr,
                  let addrlen = info?.pointee.ai_addrlen else { return nil }
            guard getnameinfo(addr, addrlen, &hostBuffer, socklen_t(NI_MAXHOST), nil, 0, NI_NAMEREQD) == 0 else { return nil }
            let bytes = hostBuffer.map(UInt8.init)
            let terminator = bytes.firstIndex(of: 0) ?? bytes.endIndex
            return String(decoding: bytes[..<terminator], as: UTF8.self)
        }.value

        hostnameCache[address] = result
        return result
    }

    /// Runs `lsof -iTCP -sTCP:ESTABLISHED` and returns a set of raw connection strings.
    private func establishedConnections() -> Set<String> {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-iTCP", "-sTCP:ESTABLISHED", "-P", "-n"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        #if DEBUG
        print("[WAN] lsof termination status: \(task.terminationStatus)")
        #endif

        guard task.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8) else {
            #if DEBUG
            print("[WAN] lsof failed or produced no output")
            #endif
            return []
        }

        let lines = output.components(separatedBy: .newlines)
        #if DEBUG
        print("[WAN] lsof raw lines: \(lines.count)")
        if let first = lines.first { print("[WAN] lsof header: \(first)") }
        #endif

        var result = Set<String>()
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            result.insert(trimmed)
        }
        #if DEBUG
        print("[WAN] lsof parsed connections: \(result.count)")
        #endif
        return result
    }

    // MARK: - Parsing

    private struct RawConnection {
        let command: String
        let pid: Int32
        let localAddress: String
        let localPort: Int
        let remoteAddress: String
        let remotePort: Int
    }

    private func parseConnectionKey(_ line: String) -> RawConnection? {
        let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard parts.count >= 9 else { return nil }
        guard let pid = Int32(parts[1]) else { return nil }

        let nameField = parts[8]
        guard let arrowRange = nameField.range(of: "->") else { return nil }

        let local = String(nameField[..<arrowRange.lowerBound])
        let remote = String(nameField[arrowRange.upperBound...])

        guard let (localAddr, localPort) = parseEndpoint(local),
              let (remoteAddr, remotePort) = parseEndpoint(remote) else { return nil }

        let command = parts[0]
            .replacingOccurrences(of: "\\x20", with: " ")
            .replacingOccurrences(of: "\\x2f", with: "/")

        return RawConnection(
            command: command,
            pid: pid,
            localAddress: localAddr,
            localPort: localPort,
            remoteAddress: remoteAddr,
            remotePort: remotePort
        )
    }

    private func parseEndpoint(_ endpoint: String) -> (String, Int)? {
        // IPv6: [::1]:1234
        if endpoint.hasPrefix("[") {
            guard let bracketEnd = endpoint.firstIndex(of: "]") else { return nil }
            let addr = String(endpoint[endpoint.startIndex...bracketEnd].dropFirst().dropLast())
            let portPart = String(endpoint[endpoint.index(after: bracketEnd)...]).trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            guard let port = Int(portPart) else { return nil }
            return (addr, port)
        }
        // IPv4: 1.2.3.4:443
        guard let colonIdx = endpoint.lastIndex(of: ":") else { return nil }
        let addr = String(endpoint[..<colonIdx])
        let portString = String(endpoint[endpoint.index(after: colonIdx)...])
        guard let port = Int(portString) else { return nil }
        return (addr, port)
    }

    // MARK: - Alert construction

    private func buildAlert(_ conn: RawConnection) -> WANConnectionAlert {
        let app = NSRunningApplication(processIdentifier: conn.pid)
        let displayName = app?.localizedName ?? conn.command
        let bundleID = app?.bundleIdentifier

        let endpoint = "\(conn.remoteAddress):\(conn.remotePort)"
        let risk = assessRisk(processName: conn.command, bundleID: bundleID, port: conn.remotePort)
        let reason = ConnectionAdvisor.reason(process: displayName, port: conn.remotePort)
        let advice = ConnectionAdvisor.advice(risk: risk, process: displayName, endpoint: endpoint)

        return WANConnectionAlert(
            id: "\(conn.pid)-\(conn.remoteAddress)-\(conn.remotePort)-\(Date().timeIntervalSince1970)",
            pid: conn.pid,
            processName: conn.command,
            bundleID: bundleID,
            remoteAddress: conn.remoteAddress,
            remotePort: conn.remotePort,
            localAddress: conn.localAddress,
            localPort: conn.localPort,
            protocolName: "TCP",
            timestamp: Date(),
            risk: risk,
            advice: advice,
            reason: reason
        )
    }

    // MARK: - Risk assessment

    private func assessRisk(processName: String, bundleID: String?, port: Int) -> WANAlertRisk {
        let lower = processName.lowercased()

        if let bundle = bundleID {
            if bundle.hasPrefix("com.apple.") {
                return .low
            }
            if ConnectionAdvisor.trustedBundles.contains(bundle) {
                return .low
            }
        }

        if let known = ConnectionAdvisor.knownApps[lower] {
            return known.risk
        }

        if lower.contains("helper") || lower.contains("agent") || lower.contains("daemon") {
            return .medium
        }

        let sensitivePorts: Set<Int> = [22, 23, 25, 110, 143, 3389, 5900, 8080]
        if sensitivePorts.contains(port) {
            return .medium
        }

        if port == 443 || port == 80 {
            return .medium
        }

        return .high
    }

    // MARK: - Address classification

    private func isPrivateAddress(_ address: String) -> Bool {
        let trimmed = address.lowercased()
        if trimmed == "localhost" || trimmed == "127.0.0.1" || trimmed == "::1" {
            return true
        }

        // IPv4 private ranges
        if let ipv4 = IPv4(trimmed) {
            if ipv4.isIn(10, 0, 0, 0, 8) { return true }
            if ipv4.isIn(172, 16, 0, 0, 12) { return true }
            if ipv4.isIn(192, 168, 0, 0, 16) { return true }
            if ipv4.isIn(169, 254, 0, 0, 16) { return true }  // link-local
            if ipv4.isIn(224, 0, 0, 0, 4) { return true }     // multicast
            return false
        }

        // IPv6 link-local / unique-local (fc00::/7) / loopback / multicast
        if trimmed.hasPrefix("fe80:") || trimmed.hasPrefix("fc") ||
           trimmed.hasPrefix("fd") || trimmed.hasPrefix("ff00:") ||
           trimmed == "::1" {
            return true
        }

        return false
    }
}

// MARK: - IPv4 helper

private struct IPv4 {
    let octets: [UInt8]
    init?(_ string: String) {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4,
              let o = parts.compactMap({ UInt8($0) }) as [UInt8]?,
              o.count == 4 else { return nil }
        octets = o
    }

    func isIn(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8, _ prefix: Int) -> Bool {
        let mask = UInt32(0xFFFFFFFF) << (32 - prefix)
        let addr = (UInt32(octets[0]) << 24) | (UInt32(octets[1]) << 16) |
                   (UInt32(octets[2]) << 8)  | UInt32(octets[3])
        let net = (UInt32(a) << 24) | (UInt32(b) << 16) |
                  (UInt32(c) << 8)  | UInt32(d)
        return (addr & mask) == (net & mask)
    }
}

// MARK: - Connection Advisor

private enum ConnectionAdvisor {
    static let trustedBundles: Set<String> = [
        "com.apple.Safari",
        "com.apple.mail",
        "com.apple.iChat",
        "com.apple.Notes",
        "com.apple.reminders",
        "com.apple.dt.Xcode"
    ]

    struct KnownApp {
        let description: String
        let risk: WANAlertRisk
    }

    static let knownApps: [String: KnownApp] = [
        "syncthing": KnownApp(description: "Syncthing peer-to-peer file sync", risk: .low)
    ]

    static func reason(process: String, port: Int) -> String {
        let lower = process.lowercased()
        if let known = knownApps[lower] {
            return "\(known.description)."
        }
        if let portReason = portReasons[port] {
            return "\(process) is using \(portReason)."
        }
        return "\(process) opened an outbound TCP connection to port \(port)."
    }

    static func advice(risk: WANAlertRisk, process: String, endpoint: String) -> String {
        switch risk {
        case .low:
            return "\(process) is contacting \(endpoint). This is a recognised app or service and is usually expected."
        case .medium:
            return "\(process) is contacting \(endpoint). If you recognise the app and were expecting it to use the network, this is normal. Otherwise you can silence this endpoint."
        case .high:
            return "\(process) is making an unusual outbound connection to \(endpoint). If you did not recently launch or authorise this app, consider investigating it in the Processes panel."
        }
    }

    private static let portReasons: [Int: String] = [
        53:    "DNS to look up a domain name",
        80:    "unencrypted HTTP web traffic",
        443:   "encrypted HTTPS web traffic",
        123:   "NTP to synchronise the system clock",
        25:    "SMTP to send email",
        110:   "POP3 to receive email",
        143:   "IMAP to sync email",
        465:   "SMTPS (encrypted email sending)",
        587:   "SMTP submission (encrypted email sending)",
        993:   "IMAPS (encrypted email sync)",
        995:   "POP3S (encrypted email retrieval)",
        22:    "SSH for remote shell access",
        3389:  "Remote Desktop Protocol",
        5900:  "VNC screen sharing",
        22000: "Syncthing sync protocol (peer-to-peer file sync)",
        21027: "Syncthing local discovery",
        8384:  "Syncthing web GUI"
    ]
}
