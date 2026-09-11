import Foundation
import Network

// Thread-safe ring buffer for OSC messages — @unchecked Sendable because NSLock protects access
final class OSCCollector: @unchecked Sendable {
    private var listener: NWListener?
    private var buffer: [OSCMessage] = []
    private let lock = NSLock()
    private(set) var port: UInt16 = 8000
    private(set) var isListening = false

    // MARK: - Lifecycle
    func start(on port: UInt16 = 8000) {
        self.port = port
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        // If port is already in use, the listener creation will succeed but the
        // state will move to .failed. NWListener handles this via stateUpdateHandler.
        guard let listener = try? NWListener(using: params,
                                             on: NWEndpoint.Port(integerLiteral: port)) else { return }
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isListening = true
            case .failed:
                // Port already in use or other error — stop cleanly
                self?.isListening = false
                listener.cancel()
            default:
                break
            }
        }
        listener.start(queue: .global(qos: .utility))
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isListening = false
    }

    // MARK: - Connection handling
    private func handle(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))

        @Sendable func receive() {
            connection.receive(minimumIncompleteLength: 1,
                               maximumLength: 65_536) { [weak self] data, _, _, error in
                if let data, !data.isEmpty {
                    if let msg = OSCCollector.parse(data) {
                        self?.push(msg)
                    }
                }
                if error == nil { receive() }
            }
        }
        receive()
    }

    // MARK: - Buffer
    private func push(_ msg: OSCMessage) {
        lock.withLock {
            buffer.insert(msg, at: 0)
            if buffer.count > 80 { buffer = Array(buffer.prefix(80)) }
        }
    }

    func drain() -> [OSCMessage] {
        lock.withLock {
            defer { buffer.removeAll() }
            return buffer
        }
    }

    // MARK: - OSC Parsing
    static func parse(_ data: Data) -> OSCMessage? {
        // Handle #bundle
        if data.starts(with: Data("#bundle\0".utf8)) {
            return parseBundle(data)
        }
        return parseMessage(data)
    }

    private static func parseMessage(_ data: Data) -> OSCMessage? {
        var offset = 0

        // 1. Address string
        guard let (address, afterAddr) = readString(data, at: offset), address.hasPrefix("/") else {
            return nil
        }
        offset = afterAddr

        // 2. Type tag string (optional)
        guard offset < data.count else {
            return OSCMessage(id: UUID(), address: address, typeTag: "", args: [], timestamp: .now)
        }

        let (typeTag, afterTypes) = readString(data, at: offset) ?? ("", offset)
        offset = afterTypes

        var args: [String] = []
        for ch in (typeTag.hasPrefix(",") ? typeTag.dropFirst() : Substring(typeTag)) {
            switch ch {
            case "i":
                guard offset + 4 <= data.count else { break }
                let val = data.withUnsafeBytes {
                    $0.loadUnaligned(fromByteOffset: offset, as: Int32.self).bigEndian
                }
                args.append(String(val)); offset += 4
            case "f":
                guard offset + 4 <= data.count else { break }
                let bits = data.withUnsafeBytes {
                    $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian
                }
                args.append(String(format: "%.4g", Float(bitPattern: bits))); offset += 4
            case "d":
                guard offset + 8 <= data.count else { break }
                let bits = data.withUnsafeBytes {
                    $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self).bigEndian
                }
                args.append(String(format: "%.6g", Double(bitPattern: bits))); offset += 8
            case "s":
                if let (str, after) = readString(data, at: offset) {
                    args.append("\"\(str)\""); offset = after
                }
            case "b":
                guard offset + 4 <= data.count else { break }
                let len = Int(data.withUnsafeBytes {
                    $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian
                })
                offset += 4 + pad4(len)
                args.append("<blob \(len)B>")
            case "T": args.append("true")
            case "F": args.append("false")
            case "N": args.append("nil")
            case "I": args.append("∞")
            case "m":
                guard offset + 4 <= data.count else { break }
                let b = data[offset..<offset+4].map { String(format: "%02X", $0) }.joined(separator: " ")
                args.append("MIDI(\(b))"); offset += 4
            default: break
            }
        }

        return OSCMessage(id: UUID(), address: address, typeTag: String(typeTag.hasPrefix(",") ? typeTag.dropFirst() : Substring(typeTag)), args: args, timestamp: .now)
    }

    private static func parseBundle(_ data: Data) -> OSCMessage? {
        var offset = 16  // Skip "#bundle\0" (8) + timetag (8)
        while offset + 4 <= data.count {
            let size = Int(data.withUnsafeBytes {
                $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian
            })
            offset += 4
            guard size > 0, offset + size <= data.count else { break }
            if let msg = parseMessage(Data(data[offset..<offset+size])) { return msg }
            offset += size
        }
        return nil
    }

    // MARK: - Helpers
    private static func readString(_ data: Data, at start: Int) -> (String, Int)? {
        guard start < data.count else { return nil }
        var end = start
        while end < data.count, data[end] != 0 { end += 1 }
        guard let str = String(data: data[start..<end], encoding: .utf8) else { return nil }
        return (str, start + pad4(end - start + 1))
    }

    private static func pad4(_ n: Int) -> Int { (n + 3) & ~3 }
}
