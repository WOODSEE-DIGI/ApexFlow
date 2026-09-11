import Darwin
import Foundation

actor NetworkCollector {
    private var previousRx: [String: UInt64] = [:]
    private var previousTx: [String: UInt64] = [:]
    private var previousTime: Date = .now

    func collect() -> NetworkSnapshot {
        let now = Date()
        let elapsed = now.timeIntervalSince(previousTime)
        previousTime = now

        // Get current byte counts via sysctl NET_RT_IFLIST2
        var ifBytes: [String: (rx: UInt64, tx: UInt64)] = [:]
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len = 0
        guard sysctl(&mib, 6, nil, &len, nil, 0) == 0, len > 0 else {
            return NetworkSnapshot(interfaces: [], timestamp: now)
        }
        var buf = [UInt8](repeating: 0, count: len)
        guard sysctl(&mib, 6, &buf, &len, nil, 0) == 0 else {
            return NetworkSnapshot(interfaces: [], timestamp: now)
        }

        var offset = 0
        while offset < len {
            // Ensure enough bytes remain to safely load an if_msghdr
            guard offset + MemoryLayout<if_msghdr>.size <= len else { break }

            let ifm = buf.withUnsafeBytes { $0.load(fromByteOffset: offset, as: if_msghdr.self) }
            let msgLen = Int(ifm.ifm_msglen)
            guard msgLen > 0 else { break }  // prevent infinite loop on malformed data

            if ifm.ifm_type == RTM_IFINFO2,
               offset + MemoryLayout<if_msghdr2>.size <= len {
                let if2m = buf.withUnsafeBytes { $0.load(fromByteOffset: offset, as: if_msghdr2.self) }
                // Interface name is in sockaddr_dl after the struct
                let sdlOffset = offset + MemoryLayout<if_msghdr2>.size
                if sdlOffset + MemoryLayout<sockaddr_dl>.size <= len {
                    let sdl = buf.withUnsafeBytes { $0.load(fromByteOffset: sdlOffset, as: sockaddr_dl.self) }
                    let nameLen = Int(sdl.sdl_nlen)
                    if nameLen > 0 && nameLen < 32 {
                        var nameBytes = [CChar](repeating: 0, count: nameLen + 1)
                        withUnsafeBytes(of: sdl.sdl_data) { data in
                            for i in 0..<nameLen { nameBytes[i] = CChar(data[i]) }
                        }
                        let name = nameBytes.withUnsafeBufferPointer { ptr -> String in
                            guard let baseAddress = ptr.baseAddress else { return "" }
                            return String(cString: baseAddress)
                        }
                        ifBytes[name] = (UInt64(if2m.ifm_data.ifi_ibytes),
                                         UInt64(if2m.ifm_data.ifi_obytes))
                    }
                }
            }

            offset += msgLen
        }

        // Get IP addresses and connected state via getifaddrs
        var ifAddrs: UnsafeMutablePointer<ifaddrs>? = nil
        getifaddrs(&ifAddrs)
        defer { freeifaddrs(ifAddrs) }

        var ipv4Map: [String: String] = [:]
        var connectedMap: [String: Bool] = [:]

        var cursor = ifAddrs
        while let ifa = cursor {
            let name = String(cString: ifa.pointee.ifa_name)
            let flags = Int32(ifa.pointee.ifa_flags)
            connectedMap[name] = (flags & IFF_RUNNING) != 0

            if let addr = ifa.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count),
                            nil, 0, NI_NUMERICHOST)
                ipv4Map[name] = host.withUnsafeBufferPointer { ptr -> String in
                    guard let baseAddress = ptr.baseAddress else { return "" }
                    return String(cString: baseAddress)
                }
            }
            cursor = ifa.pointee.ifa_next
        }

        var snapshots: [InterfaceSnapshot] = []

        // Only show real en* interfaces: must be running AND have an IPv4 address
        // This excludes virtual en10-en16 (Thunderbolt/USB network), bridge, awdl, utun*, etc.
        for (name, (rx, tx)) in ifBytes {
            guard name.hasPrefix("en") else { continue }
            let connected = connectedMap[name] ?? false
            guard connected else { continue }
            // Require an IPv4 address — filters out unconfigured virtual adapters
            guard ipv4Map[name] != nil else { continue }

            let prevRx = previousRx[name] ?? rx
            let prevTx = previousTx[name] ?? tx
            let dlRate = elapsed > 0 ? max(0, Double(rx &- prevRx) / elapsed) : 0
            let ulRate = elapsed > 0 ? max(0, Double(tx &- prevTx) / elapsed) : 0

            previousRx[name] = rx
            previousTx[name] = tx

            snapshots.append(InterfaceSnapshot(
                name: name,
                ipv4: ipv4Map[name] ?? "",
                downloadRate: dlRate,
                uploadRate: ulRate,
                totalDownload: rx,
                totalUpload: tx,
                isConnected: connected
            ))
        }

        snapshots.sort { $0.name < $1.name }
        return NetworkSnapshot(interfaces: snapshots, timestamp: now)
    }
}
