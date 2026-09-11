import CoreMIDI
import Foundation

// Thread-safe buffer for MIDI events received from CoreMIDI callbacks.
// Must be @unchecked Sendable because it uses NSLock to protect mutable state
// accessed from both the CoreMIDI callback thread and the actor.
private final class MIDIEventBuffer: @unchecked Sendable {
    struct Event {
        let sourceName: String
        let status: UInt8      // high nibble: opcode, low nibble: channel
        let data1: UInt8
        let data2: UInt8
        let timestamp: Date
    }

    private var events: [Event] = []
    private let lock = NSLock()

    func push(_ event: Event) {
        lock.withLock {
            events.append(event)
            if events.count > 500 { events.removeFirst(200) }
        }
    }

    func drain() -> [Event] {
        lock.withLock {
            defer { events.removeAll() }
            return events
        }
    }
}

// Source name map: shared between callback and actor, protected by lock
private final class MIDISourceMap: @unchecked Sendable {
    private var map: [MIDIEndpointRef: String] = [:]
    private let lock = NSLock()

    func set(_ name: String, for ref: MIDIEndpointRef) {
        lock.withLock { map[ref] = name }
    }

    func name(for ref: MIDIEndpointRef) -> String {
        lock.withLock { map[ref] ?? "Unknown" }
    }
}

actor MIDICollector {
    private var client: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private let buffer = MIDIEventBuffer()
    private let sourceMap = MIDISourceMap()
    private var deviceInfos: [String: MIDIDeviceInfo] = [:]
    private var connectedSources: Set<MIDIEndpointRef> = []
    private var isSetup = false

    // MARK: - Setup
    func setup() {
        guard !isSetup else { return }
        isSetup = true

        MIDIClientCreate("Apex" as CFString, nil, nil, &client)

        let buf = buffer
        let srcMap = sourceMap

        // MIDIReceiveBlock is @Sendable — only capture @unchecked Sendable types
        let receiveBlock: MIDIReceiveBlock = { eventList, srcConnRefCon in
            let list = eventList.pointee
            guard list.numPackets > 0 else { return }

            // Decode source name from refCon (pointer to MIDIEndpointRef)
            var srcName = "Unknown"
            if let refCon = srcConnRefCon {
                let ref = refCon.load(as: MIDIEndpointRef.self)
                srcName = srcMap.name(for: ref)
            }

            // Walk packets using raw pointer arithmetic (MIDIEventPacketNext)
            withUnsafePointer(to: list.packet) { firstPtr in
                var ptr = UnsafeMutablePointer(mutating: firstPtr)
                for _ in 0..<list.numPackets {
                    let packet = ptr.pointee
                    // Process first word (MIDI 1.0 UMP channel voice = type 0x2)
                    if packet.wordCount > 0 {
                        let word = packet.words.0
                        let msgType = (word >> 28) & 0xF
                        if msgType == 2 {
                            let status = UInt8((word >> 16) & 0xFF)
                            let data1  = UInt8((word >> 8)  & 0xFF)
                            let data2  = UInt8( word         & 0xFF)
                            buf.push(.init(sourceName: srcName, status: status,
                                           data1: data1, data2: data2, timestamp: .now))
                        }
                    }
                    ptr = MIDIEventPacketNext(ptr)
                }
            }
        }

        // kMIDIProtocol_1_0 = 1 — use raw value to avoid Swift import naming ambiguity
        MIDIInputPortCreateWithProtocol(client, "Apex Input" as CFString,
                                        MIDIProtocolID(rawValue: 1)!, &inputPort, receiveBlock)
        connectAllSources()
    }

    // MARK: - Source management
    private func connectAllSources() {
        let count = MIDIGetNumberOfSources()
        for i in 0..<count {
            let src = MIDIGetSource(i)
            guard !connectedSources.contains(src) else { continue }
            let name = midiStringProperty(src, kMIDIPropertyName) ?? "Source \(i)"
            sourceMap.set(name, for: src)
            MIDIPortConnectSource(inputPort, src, nil)
            connectedSources.insert(src)
        }
    }

    // MARK: - Collect
    func collect() -> [MIDIDeviceInfo] {
        connectAllSources()

        // Build fresh device list from current sources
        let srcCount = MIDIGetNumberOfSources()
        var current: [String: MIDIDeviceInfo] = [:]
        for i in 0..<srcCount {
            let src = MIDIGetSource(i)
            let name = midiStringProperty(src, kMIDIPropertyName) ?? "MIDI Source \(i)"
            let mfg  = midiStringProperty(src, kMIDIPropertyManufacturer) ?? ""
            var info = deviceInfos[name] ?? MIDIDeviceInfo(id: name, name: name, manufacturer: mfg)
            info.isOnline = true
            // Decay channel activity each poll (bits fade out)
            info.channelActivity = info.channelActivity >> 1
            current[name] = info
        }

        // Process buffered events
        let events = buffer.drain()
        for event in events {
            let opcode  = (event.status & 0xF0) >> 4
            let channel = event.status & 0x0F
            let src = event.sourceName

            var info = current[src] ?? MIDIDeviceInfo(id: src, name: src, manufacturer: "")
            info.channelActivity |= (1 << channel)
            info.messageCount += 1
            info.lastMessage = decodeMIDI(opcode: opcode, channel: channel,
                                          d1: event.data1, d2: event.data2)
            current[src] = info
        }

        deviceInfos = current
        return Array(current.values).sorted { $0.name < $1.name }
    }

    // MARK: - Helpers
    private func midiStringProperty(_ obj: MIDIObjectRef, _ key: CFString) -> String? {
        var ref: Unmanaged<CFString>? = nil
        guard MIDIObjectGetStringProperty(obj, key, &ref) == noErr else { return nil }
        return ref?.takeRetainedValue() as String?
    }

    private func decodeMIDI(opcode: UInt8, channel: UInt8, d1: UInt8, d2: UInt8) -> String {
        let ch = Int(channel) + 1
        switch opcode {
        case 0x9 where d2 > 0:
            return "Ch\(ch) NoteOn \(noteName(d1)) vel \(d2)"
        case 0x8, 0x9:
            return "Ch\(ch) NoteOff \(noteName(d1))"
        case 0xB:
            return "Ch\(ch) CC\(d1) = \(d2)"
        case 0xC:
            return "Ch\(ch) PC \(d1)"
        case 0xD:
            return "Ch\(ch) ChanPres \(d1)"
        case 0xE:
            let bend = (Int(d2) << 7 | Int(d1)) - 8192
            return "Ch\(ch) Bend \(bend)"
        case 0xA:
            return "Ch\(ch) PolyPres \(noteName(d1)) \(d2)"
        default:
            return String(format: "Ch%d 0x%02X %02X %02X", ch, opcode << 4, d1, d2)
        }
    }

    private func noteName(_ n: UInt8) -> String {
        let names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        return "\(names[Int(n) % 12])\(Int(n) / 12 - 1)"
    }
}
