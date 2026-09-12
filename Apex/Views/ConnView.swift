import SwiftUI
import Charts
import CoreBluetooth
import AppKit

struct ConnView: View {
    let conn: ConnData

    var body: some View {
        VStack(spacing: 8) {
            // Row 1: WiFi | Bluetooth | Thunderbolt (with sparklines) | USB
            HStack(alignment: .top, spacing: 14) {
                WiFiSection(wifi: conn.wifi)
                Divider().background(Theme.surface1)
                BTSection(devices: conn.bluetoothDevices)
                Divider().background(Theme.surface1)
                TBSection(devices: conn.thunderboltDevices)
                Divider().background(Theme.surface1)
                USBSection(devices: conn.usbDevices)
            }

            Divider().background(Theme.surface1.opacity(0.5))

            // Row 2: MIDI | OSC
            HStack(alignment: .top, spacing: 14) {
                MIDISection(devices: conn.midiDevices)
                Divider().background(Theme.surface1)
                OSCSection(messages: conn.oscMessages,
                           port: conn.oscPort,
                           isListening: conn.oscListening)
            }
        }
        .padding(Theme.panelPadding)
    }
}

// MARK: - WiFi Section
private struct WiFiSection: View {
    let wifi: WiFiInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionHeader(icon: "wifi", label: "WiFi", color: Theme.wifiColor)
            if wifi.isConnected {
                HStack(alignment: .center, spacing: 5) {
                    SignalBarView(bars: wifi.signalBars, color: Theme.wifiColor)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(wifi.ssid.isEmpty ? "Connected" : wifi.ssid)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.text).lineLimit(1)
                        Text(wifi.band)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(Theme.overlay1)
                    }
                }
                StatLabel(key: "RSSI", value: "\(wifi.rssi) dBm",
                          valueColor: Theme.loadColor(signalQuality))
                StatLabel(key: "Link", value: String(format: "%.0f Mbps", wifi.linkRate))
                if wifi.channel > 0 { StatLabel(key: "Ch", value: "\(wifi.channel)") }
                if !wifi.security.isEmpty { StatLabel(key: "Sec", value: wifi.security) }
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "wifi.slash").font(.system(size: 10)).foregroundStyle(Theme.overlay0)
                    Text("No WiFi").font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.overlay0)
                }
            }
        }
        .frame(minWidth: 110)
    }

    private var signalQuality: Double { max(0, min(1, Double(wifi.rssi + 100) / 50)) }
}

// MARK: - Bluetooth Section
private struct BTSection: View {
    let devices: [BTDevice]
    @State private var btAuth: CBManagerAuthorization = CBCentralManager.authorization

    private var connected: [BTDevice]    { devices.filter {  $0.isConnected } }
    private var disconnected: [BTDevice] { devices.filter { !$0.isConnected } }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                SectionHeader(icon: "dot.radiowaves.left.and.right", label: "Bluetooth", color: Theme.btColor)
                Spacer()
                if !devices.isEmpty {
                    Text("\(connected.count)/\(devices.count)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(Theme.overlay0)
                }
            }

            // Permission banner
            switch btAuth {
            case .denied, .restricted:
                Button(action: openBluetoothSettings) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8)).foregroundStyle(Theme.yellow)
                        Text("Permission denied — Open Settings")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(Theme.yellow)
                    }
                }
                .buttonStyle(.plain)
            case .notDetermined:
                Text("Requesting Bluetooth access…")
                    .font(.system(size: 8, design: .monospaced)).foregroundStyle(Theme.overlay0)
            default:
                EmptyView()
            }

            if devices.isEmpty && btAuth == .allowedAlways {
                Text("No paired devices").font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.overlay0)
            } else if !devices.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(connected)    { device in BTDeviceRow(device: device) }
                        ForEach(disconnected) { device in BTDeviceRow(device: device) }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .frame(minWidth: 140)
        .onAppear { btAuth = CBCentralManager.authorization }
        .task {
            // Re-poll every 2s so the banner dismisses as soon as permission is granted
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                btAuth = CBCentralManager.authorization
            }
        }
    }

    private func openBluetoothSettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")!
        )
    }
}

private struct BTDeviceRow: View {
    let device: BTDevice

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: device.type.systemImage)
                .font(.system(size: 10))
                .foregroundStyle(device.isConnected ? Theme.btColor : Theme.overlay0)
                .frame(width: 12)
            VStack(alignment: .leading, spacing: 0) {
                Text(device.name)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(device.isConnected ? Theme.text : Theme.overlay1)
                    .lineLimit(1)
                Text(device.isConnected ? "\(device.rssi) dBm" : "not connected")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(Theme.overlay0)
            }
            Spacer()
            if device.isConnected {
                SignalBarView(bars: device.signalBars, color: Theme.btColor)
            }
        }
        .opacity(device.isConnected ? 1.0 : 0.45)
    }
}

// MARK: - Thunderbolt Section (with I/O sparklines)
private struct TBSection: View {
    let devices: [TBDevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            SectionHeader(icon: "bolt.fill", label: "Thunderbolt", color: Theme.tbColor)
            if devices.isEmpty {
                Text("No ports").font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.overlay0)
            } else {
                ForEach(devices) { port in TBPortRow(port: port) }
            }
        }
        .frame(minWidth: 220)
    }
}

private struct TBPortRow: View {
    let port: TBDevice

    var body: some View {
        HStack(spacing: 5) {
            Text("P\(port.portNumber + 1)")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.overlay0).frame(width: 14, alignment: .leading)
            Circle().fill(port.isConnected ? Theme.green : Theme.surface2).frame(width: 5, height: 5)
            SpeedBadge(label: port.speedShort, color: Theme.tbColor)

            if port.isConnected {
                if port.mode != .unknown {
                    Text(port.mode.label)
                        .font(.system(size: 7, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.yellow.opacity(0.7))
                }
                Text(port.connectedDevice.isEmpty ? port.vendor : port.connectedDevice)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Theme.text).lineLimit(1).truncationMode(.middle)
                Spacer()
                // I/O sparklines for storage ports
                if port.isStoragePort && !port.readHistory.isEmpty {
                    TBSparkline(readHistory: port.readHistory, writeHistory: port.writeHistory)
                }
            } else {
                Text("empty").font(.system(size: 8, design: .monospaced)).foregroundStyle(Theme.overlay0)
            }
        }
    }
}

private struct TBSparkline: View {
    let readHistory: [DataPoint]
    let writeHistory: [DataPoint]

    private var peak: Double {
        max(readHistory.map(\.value).max() ?? 0,
            writeHistory.map(\.value).max() ?? 0,
            1_048_576)
    }

    var body: some View {
        Chart {
            ForEach(readHistory) { p in
                AreaMark(x: .value("t", p.time), y: .value("r", p.value))
                    .foregroundStyle(Theme.diskRead.opacity(0.5))
            }
            ForEach(writeHistory) { p in
                LineMark(x: .value("t", p.time), y: .value("w", p.value))
                    .foregroundStyle(Theme.diskWrite).lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXAxis(.hidden).chartYAxis(.hidden)
        .chartYScale(domain: 0...peak)
        .frame(width: 50, height: 16)
    }
}

// MARK: - USB Section
private struct USBSection: View {
    let devices: [USBDevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                SectionHeader(icon: "cable.connector", label: "USB", color: Theme.usbColor)
                Spacer()
                if !devices.isEmpty {
                    Text("\(devices.count)").font(.system(size: 8, design: .monospaced)).foregroundStyle(Theme.overlay0)
                }
            }
            if devices.isEmpty {
                Text("No devices").font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.overlay0)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(devices) { device in USBDeviceRow(device: device) }
                    }
                }
            }
        }
        .frame(minWidth: 150)
    }
}

private struct USBDeviceRow: View {
    let device: USBDevice

    var body: some View {
        HStack(spacing: 5) {
            SpeedBadge(label: device.speed.rawValue, color: speedColor)
            VStack(alignment: .leading, spacing: 0) {
                Text(device.name)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.text).lineLimit(1).truncationMode(.middle)
                if !device.vendor.isEmpty {
                    Text(device.vendor).font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(Theme.overlay0).lineLimit(1)
                }
            }
            Spacer()
            // I/O sparkline for USB mass-storage devices
            if device.isStorageLike && !device.readHistory.isEmpty {
                USBSparkline(readHistory: device.readHistory, writeHistory: device.writeHistory)
            }
        }
    }

    private var speedColor: Color {
        switch device.speed {
        case .superSpeedPlus, .usb4: return Theme.yellow
        case .superSpeed:            return Theme.teal
        case .highSpeed:             return Theme.blue
        default:                     return Theme.overlay1
        }
    }
}

private struct USBSparkline: View {
    let readHistory: [DataPoint]
    let writeHistory: [DataPoint]

    private var peak: Double {
        max(readHistory.map(\.value).max() ?? 0,
            writeHistory.map(\.value).max() ?? 0,
            1_048_576)
    }

    var body: some View {
        Chart {
            ForEach(readHistory) { p in
                AreaMark(x: .value("t", p.time), y: .value("r", p.value))
                    .foregroundStyle(Theme.diskRead.opacity(0.5))
            }
            ForEach(writeHistory) { p in
                LineMark(x: .value("t", p.time), y: .value("w", p.value))
                    .foregroundStyle(Theme.diskWrite).lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXAxis(.hidden).chartYAxis(.hidden)
        .chartYScale(domain: 0...peak)
        .frame(width: 45, height: 14)
    }
}

// MARK: - MIDI Section
private struct MIDISection: View {
    let devices: [MIDIDeviceInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(icon: "pianokeys", label: "MIDI", color: Theme.mauve)
            if devices.isEmpty {
                Text("No MIDI devices").font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.overlay0)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(devices) { device in MIDIDeviceRow(device: device) }
                    }
                }
            }
        }
        .frame(minWidth: 200)
    }
}

private struct MIDIDeviceRow: View {
    let device: MIDIDeviceInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(device.isOnline ? Theme.green : Theme.surface2).frame(width: 5, height: 5)
                Text(device.name)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.text).lineLimit(1)
                Spacer()
                if device.messageCount > 0 {
                    Text("\(device.messageCount)").font(.system(size: 7, design: .monospaced)).foregroundStyle(Theme.overlay0)
                }
            }

            // 16-channel activity grid
            HStack(spacing: 2) {
                ForEach(0..<16, id: \.self) { ch in
                    let active = (device.channelActivity >> ch) & 1 == 1
                    RoundedRectangle(cornerRadius: 1)
                        .fill(active ? Theme.mauve : Theme.surface1)
                        .frame(width: 7, height: 7)
                        .overlay(
                            Text("\(ch + 1)").font(.system(size: 4)).foregroundStyle(active ? Theme.crust : Theme.overlay0)
                        )
                }
            }

            if !device.lastMessage.isEmpty {
                Text(device.lastMessage)
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(Theme.mauve.opacity(0.8)).lineLimit(1)
            }
            if !device.manufacturer.isEmpty {
                Text(device.manufacturer).font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(Theme.overlay0).lineLimit(1)
            }
        }
        .padding(.vertical, 2).padding(.horizontal, 4)
        .background(Theme.surface1.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - OSC Section
private struct OSCSection: View {
    let messages: [OSCMessage]
    let port: Int
    let isListening: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                SectionHeader(icon: "waveform", label: "OSC", color: Theme.sky)
                SpeedBadge(label: ":\(port)", color: isListening ? Theme.sky : Theme.overlay0)
                if isListening {
                    Circle().fill(Theme.green).frame(width: 5, height: 5)
                }
                Spacer()
                if !messages.isEmpty {
                    Text("\(messages.count)").font(.system(size: 8, design: .monospaced)).foregroundStyle(Theme.overlay0)
                }
            }

            if messages.isEmpty {
                Text("UDP :\(port)  —  no messages yet")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.overlay0)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(messages.prefix(30)) { msg in OSCMessageRow(msg: msg) }
                    }
                }
            }
        }
        .frame(minWidth: 200, maxWidth: .infinity)
    }
}

private struct OSCMessageRow: View {
    let msg: OSCMessage

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f
    }()

    var body: some View {
        HStack(spacing: 4) {
            Text(msg.address)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.sky).lineLimit(1)
            if !msg.argsDisplay.isEmpty {
                Text(msg.argsDisplay)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Theme.text).lineLimit(1).truncationMode(.tail)
            }
            Spacer()
            Text(Self.timeFmt.string(from: msg.timestamp))
                .font(.system(size: 7, design: .monospaced)).foregroundStyle(Theme.overlay0)
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Shared section header
private struct SectionHeader: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8, weight: .semibold)).foregroundStyle(color)
            Text(label).font(.system(size: 8, weight: .semibold, design: .monospaced)).foregroundStyle(color)
        }
    }
}
