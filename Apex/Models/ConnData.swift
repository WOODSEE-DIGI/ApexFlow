import Foundation
import Observation

// MARK: - WiFi
struct WiFiInfo: Sendable {
    var ssid: String = ""
    var rssi: Int = 0          // dBm (negative)
    var linkRate: Double = 0   // Mbps
    var channel: Int = 0
    var band: String = ""      // "2.4 GHz", "5 GHz", "6 GHz"
    var security: String = ""
    var isConnected: Bool = false

    /// 0–4 bar strength from RSSI
    var signalBars: Int {
        if rssi >= -50 { return 4 }
        if rssi >= -65 { return 3 }
        if rssi >= -75 { return 2 }
        if rssi >= -85 { return 1 }
        return 0
    }
}

// MARK: - Bluetooth
enum BTDeviceType: String, Sendable {
    case phone, computer, headphones, keyboard, mouse, gamepad, wearable, unknown

    var systemImage: String {
        switch self {
        case .phone:       return "iphone"
        case .computer:    return "laptopcomputer"
        case .headphones:  return "headphones"
        case .keyboard:    return "keyboard"
        case .mouse:       return "computermouse"
        case .gamepad:     return "gamecontroller"
        case .wearable:    return "applewatch"
        case .unknown:     return "dot.radiowaves.left.and.right"
        }
    }
}

struct BTDevice: Identifiable, Sendable {
    let id: String  // Bluetooth address
    var name: String
    var type: BTDeviceType
    var rssi: Int   // dBm
    var isConnected: Bool

    var signalBars: Int {
        if rssi >= -50 { return 4 }
        if rssi >= -65 { return 3 }
        if rssi >= -75 { return 2 }
        if rssi >= -85 { return 1 }
        return 0
    }
}

// MARK: - Thunderbolt
struct TBDevice: Identifiable, Sendable {
    let id: String
    var portNumber: Int
    var linkSpeed: String       // e.g. "40 Gb/s", "Up to 40 Gb/s"
    var isConnected: Bool
    var connectedDevice: String // device name, empty if nothing plugged in
    var vendor: String
    var mode: TBMode

    enum TBMode: String, Sendable {
        case thunderbolt3 = "thunderbolt_three"
        case thunderbolt4 = "usb_four"
        case usb4         = "usb4_gen2x2"
        case unknown      = ""

        var label: String {
            switch self {
            case .thunderbolt3: return "TB3"
            case .thunderbolt4: return "TB4"
            case .usb4:         return "USB4"
            case .unknown:      return "TB"
            }
        }

        init(raw: String) {
            switch raw {
            case "thunderbolt_three":         self = .thunderbolt3
            case "usb_four", "thunderbolt_four": self = .thunderbolt4
            case "usb4_gen2x2":               self = .usb4
            default:                          self = .unknown
            }
        }
    }

    /// Compact speed string: "40G" or "≤40G" when no device connected
    var speedShort: String {
        linkSpeed
            .replacingOccurrences(of: " Gb/s", with: "G")
            .replacingOccurrences(of: "Up to ", with: "≤")
            .trimmingCharacters(in: .whitespaces)
    }

    // I/O activity (correlated from DiskData — updated separately from ConnCollector)
    var ioReadRate:   Double = 0
    var ioWriteRate:  Double = 0
    var readHistory:  [DataPoint] = []
    var writeHistory: [DataPoint] = []

    var isStoragePort: Bool {
        isConnected && !connectedDevice.lowercased().contains("display")
    }
}

// MARK: - USB
enum USBSpeed: String, Sendable {
    case lowSpeed   = "LS"
    case fullSpeed  = "FS"
    case highSpeed  = "HS"
    case superSpeed = "SS"
    case superSpeedPlus = "SS+"
    case usb4       = "USB4"
    case unknown    = "?"

    init(rawValue deviceSpeed: Int) {
        switch deviceSpeed {
        case 1:  self = .lowSpeed
        case 2:  self = .fullSpeed
        case 3:  self = .highSpeed
        case 4:  self = .superSpeed
        case 5:  self = .superSpeedPlus
        case 6:  self = .usb4
        default: self = .unknown
        }
    }
}

struct USBDevice: Identifiable, Sendable {
    let id: String
    var name: String
    var vendor: String
    var speed: USBSpeed
    var vendorID: Int
    var productID: Int
    var lastSeen: Date = .now
    var children: [USBDevice] = []

    var isStorageLike: Bool {
        speed == .superSpeed || speed == .superSpeedPlus || speed == .usb4
    }
}

// MARK: - MIDI
struct MIDIDeviceInfo: Identifiable, Sendable {
    let id: String          // device name used as stable ID
    var name: String
    var manufacturer: String
    var isOnline: Bool = true
    var channelActivity: UInt16 = 0  // bitmask channels 1-16
    var lastMessage: String = ""
    var messageCount: Int = 0

    var activeChannels: [Int] {
        (0..<16).filter { (channelActivity >> $0) & 1 == 1 }.map { $0 + 1 }
    }
}

// MARK: - OSC
struct OSCMessage: Identifiable, Sendable {
    let id: UUID
    var address: String
    var typeTag: String
    var args: [String]
    var timestamp: Date

    var argsDisplay: String { args.joined(separator: "  ") }
}

// MARK: - Observable model
struct ConnSnapshot: Sendable {
    let wifi: WiFiInfo
    let bluetoothDevices: [BTDevice]
    let thunderboltDevices: [TBDevice]
    let usbDevices: [USBDevice]
    let midiDevices: [MIDIDeviceInfo]
}

@Observable
@MainActor
final class ConnData {
    var wifi = WiFiInfo()
    var bluetoothDevices: [BTDevice] = []
    var thunderboltDevices: [TBDevice] = []
    var usbDevices: [USBDevice] = []
    var midiDevices: [MIDIDeviceInfo] = []
    var oscMessages: [OSCMessage] = []
    var oscPort: Int = 8000
    var oscListening: Bool = false

    static let maxOSCMessages = 80
    static let tbHistoryLength = 60

    func update(from snapshot: ConnSnapshot) {
        wifi = snapshot.wifi
        bluetoothDevices = snapshot.bluetoothDevices
        // Preserve TB I/O history when updating from connectivity snapshot
        let prevTB = Dictionary(uniqueKeysWithValues: thunderboltDevices.map { ($0.id, $0) })
        thunderboltDevices = snapshot.thunderboltDevices.map { dev in
            var updated = dev
            if let prev = prevTB[dev.id] {
                updated.ioReadRate   = prev.ioReadRate
                updated.ioWriteRate  = prev.ioWriteRate
                updated.readHistory  = prev.readHistory
                updated.writeHistory = prev.writeHistory
            }
            return updated
        }
        usbDevices = snapshot.usbDevices
        midiDevices = snapshot.midiDevices
    }

    /// Called by SystemMonitor on every disk poll to push I/O into TB port histories
    func updateTBActivity(totalReadRate: Double, totalWriteRate: Double) {
        let storagePorts = thunderboltDevices.filter { $0.isStoragePort }
        guard !storagePorts.isEmpty else { return }
        let portRead  = totalReadRate  / Double(storagePorts.count)
        let portWrite = totalWriteRate / Double(storagePorts.count)
        let now = Date()
        for i in thunderboltDevices.indices {
            let isStorage = thunderboltDevices[i].isStoragePort
            let r = isStorage ? portRead  : 0
            let w = isStorage ? portWrite : 0
            thunderboltDevices[i].ioReadRate  = r
            thunderboltDevices[i].ioWriteRate = w
            thunderboltDevices[i].readHistory.append(DataPoint(time: now, value: r))
            thunderboltDevices[i].writeHistory.append(DataPoint(time: now, value: w))
            if thunderboltDevices[i].readHistory.count  > Self.tbHistoryLength { thunderboltDevices[i].readHistory.removeFirst() }
            if thunderboltDevices[i].writeHistory.count > Self.tbHistoryLength { thunderboltDevices[i].writeHistory.removeFirst() }
        }
    }

    func addOSCMessage(_ msg: OSCMessage) {
        oscMessages.insert(msg, at: 0)
        if oscMessages.count > Self.maxOSCMessages {
            oscMessages = Array(oscMessages.prefix(Self.maxOSCMessages))
        }
    }

    func updateMIDI(from infos: [MIDIDeviceInfo]) {
        midiDevices = infos
    }

    func setOSCListening(_ listening: Bool) {
        oscListening = listening
    }
}
