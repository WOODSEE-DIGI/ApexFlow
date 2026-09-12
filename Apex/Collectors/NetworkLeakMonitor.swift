import Foundation
import Network
import AppKit

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

        guard await data.isEnabled else { return }

        for key in newKeys {
            guard let conn = parseConnectionKey(key) else { continue }
            guard !isPrivateAddress(conn.remoteAddress) else { continue }
            guard await !data.ignoredPrivate || !isPrivateAddress(conn.localAddress) else { continue }

            let alert = buildAlert(conn)
            guard await !data.isApproved(alert) else { continue }

            await MainActor.run { data.add(alert) }
        }
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
        guard task.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8) else { return [] }

        var result = Set<String>()
        for line in output.components(separatedBy: .newlines).dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            result.insert(trimmed)
        }
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
        if let bundle = bundleID {
            if bundle.hasPrefix("com.apple.") {
                return .low
            }
            if ConnectionAdvisor.trustedBundles.contains(bundle) {
                return .low
            }
        }

        let lower = processName.lowercased()
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

        // IPv6 link-local / unique-local / loopback / multicast
        if trimmed.hasPrefix("fe80:") || trimmed.hasPrefix("fc00:") ||
           trimmed.hasPrefix("fd00:") || trimmed.hasPrefix("ff00:") ||
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

    static func reason(process: String, port: Int) -> String {
        if let portReason = portReasons[port] {
            return "\(process) is using \(portReason)."
        }
        return "\(process) opened an outbound TCP connection to port \(port)."
    }

    static func advice(risk: WANAlertRisk, process: String, endpoint: String) -> String {
        switch risk {
        case .low:
            return "This is a first-party or explicitly trusted process contacting a well-known service. You can usually allow it."
        case .medium:
            return "\(process) is contacting \(endpoint). If you recognise the app and were expecting it to use the network, this is normal. Otherwise you can silence this endpoint."
        case .high:
            return "\(process) is making an unusual outbound connection. If you did not recently launch or authorise this app, consider investigating it in the Processes panel."
        }
    }

    private static let portReasons: [Int: String] = [
        53:   "DNS to look up a domain name",
        80:   "unencrypted HTTP web traffic",
        443:  "encrypted HTTPS web traffic",
        123:  "NTP to synchronise the system clock",
        25:   "SMTP to send email",
        110:  "POP3 to receive email",
        143:  "IMAP to sync email",
        465:  "SMTPS (encrypted email sending)",
        587:  "SMTP submission (encrypted email sending)",
        993:  "IMAPS (encrypted email sync)",
        995:  "POP3S (encrypted email retrieval)",
        22:   "SSH for remote shell access",
        3389: "Remote Desktop Protocol",
        5900: "VNC screen sharing"
    ]
}
