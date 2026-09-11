import Foundation
import CoreWLAN
import IOBluetooth
import CoreBluetooth
import IOKit

// Kept alive at MainActor to trigger the macOS Bluetooth permission dialog.
// IOBluetooth alone does not reliably prompt — CBCentralManager does.
@MainActor
private final class BTPermissionTrigger: NSObject, CBCentralManagerDelegate {
    static let shared = BTPermissionTrigger()
    private var manager: CBCentralManager?

    func requestIfNeeded() {
        guard manager == nil else { return }
        manager = CBCentralManager(delegate: self, queue: .main)
    }

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // No-op — existence of CBCentralManager is what triggers the dialog
    }
}

actor ConnCollector {

    // MARK: - WiFi (must run on MainActor — CoreWLAN is not thread-safe)
    func collectWiFi() async -> WiFiInfo {
        await MainActor.run {
            guard let iface = CWWiFiClient.shared().interface() else { return WiFiInfo() }
            var info = WiFiInfo()
            info.isConnected = iface.powerOn()
            info.ssid = iface.ssid() ?? (info.isConnected ? "Connected" : "")
            info.rssi = iface.rssiValue()
            info.linkRate = iface.transmitRate()
            if let ch = iface.wlanChannel() {
                info.channel = ch.channelNumber
                switch ch.channelBand {
                case .band2GHz: info.band = "2.4 GHz"
                case .band5GHz: info.band = "5 GHz"
                case .band6GHz: info.band = "6 GHz"
                default:        info.band = ""
                }
            }
            switch iface.security() {
            case .none:                         info.security = "Open"
            case .WEP:                          info.security = "WEP"
            case .wpaPersonal, .wpa2Personal:   info.security = "WPA2"
            case .wpa3Personal:                 info.security = "WPA3"
            default:                            info.security = "Secured"
            }
            return info
        }
    }

    // MARK: - Bluetooth (must run on MainActor — IOBluetooth is not thread-safe)
    func collectBluetooth() async -> [BTDevice] {
        // Trigger macOS Bluetooth permission dialog on first call
        await MainActor.run { BTPermissionTrigger.shared.requestIfNeeded() }

        return await MainActor.run {
            guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return [] }
            // Show ALL paired devices (connected and disconnected), not just active ones
            return paired.map { device in
                let majorClass = Int((device.classOfDevice >> 8) & 0x1F)
                let type: BTDeviceType
                switch majorClass {
                case 1:  type = .computer
                case 2:  type = .phone
                case 4:  type = .headphones
                case 5:
                    let minor = Int((device.classOfDevice >> 2) & 0x3F)
                    type = minor == 1 || minor == 2 ? .keyboard
                         : minor == 3 || minor == 4 ? .mouse : .unknown
                case 6:  type = .gamepad
                case 9:  type = .wearable
                default: type = .unknown
                }
                // isConnected() works for Classic BT. For BLE HID devices (Magic
                // Keyboard, Mouse, AirPods, etc.) the ACL flag can be false even when
                // active — use a non-zero RSSI as a fallback indicator.
                let rssi = Int(device.rawRSSI())
                let live = device.isConnected() || (rssi < 0 && rssi > -100)
                return BTDevice(
                    id: device.addressString,
                    name: device.name ?? "Unknown Device",
                    type: type,
                    rssi: rssi,
                    isConnected: live
                )
            }
        }
    }

    // MARK: - Thunderbolt via IOKit (sandbox-safe, all ports + connected devices)
    func collectThunderbolt() -> [TBDevice] {
        // Strategy: each IOThunderboltController owns one physical port.
        // Under each controller → switch → Port@1 is the user-facing connector.
        // Ports@2-6 are internal adapters (PCIe, USB, DP). Port@7 is upstream.
        // We only collect Port@1 from each controller's switch.

        var devices: [TBDevice] = []
        var portIndex = 0

        let match = IOServiceMatching("IOThunderboltController") as CFDictionary
        var iter: io_iterator_t = IO_OBJECT_NULL
        guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iter) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iter) }

        var service = IOIteratorNext(iter)
        while service != IO_OBJECT_NULL {
            // Controller → Port@7 (host interface) → Switch → Port@1 (physical)
            if let switchPort = findUserFacingPort(controller: service, portIndex: portIndex) {
                devices.append(switchPort)
                portIndex += 1
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iter)
        }

        return devices
    }

    /// Walks from a controller down to its Port@1 (user-facing connector)
    /// and returns a TBDevice with connection state and device info.
    private func findUserFacingPort(controller: io_service_t, portIndex: Int) -> TBDevice? {
        // Step 1: Find the controller's child IOThunderboltPort (the host interface port@7)
        guard let hostPort = findFirstChild(of: controller, matching: { _, props in
            (props["Port Number"] as? Int) == 7
                && (props["Description"] as? String ?? "").contains("Host Interface")
        }) else { return nil }
        defer { IOObjectRelease(hostPort) }

        // Step 2: Find the switch under the host interface port
        guard let switchNode = findFirstChild(of: hostPort, matching: { _, props in
            props["Max Port Number"] != nil  // Switches have "Max Port Number"
        }) else { return nil }
        defer { IOObjectRelease(switchNode) }

        // Step 3: Find Port@1 under the switch — this is the user-facing connector
        guard let userPort = findFirstChild(of: switchNode, matching: { _, props in
            (props["Port Number"] as? Int) == 1
        }) else { return nil }
        defer { IOObjectRelease(userPort) }

        // Step 4: Read port properties
        var pProps: Unmanaged<CFMutableDictionary>? = nil
        IORegistryEntryCreateCFProperties(userPort, &pProps, kCFAllocatorDefault, 0)
        guard let pp = pProps?.takeRetainedValue() as? [String: Any] else { return nil }

        let bandwidth  = pp["Maximum Bandwidth Allocated"] as? Int ?? 0
        let linkSpeed  = pp["Current Link Speed"] as? Int ?? 0
        let linkWidth  = pp["Current Link Width"] as? Int ?? 0
        let isConnected = (bandwidth > 0) || (linkSpeed > 0 && linkWidth > 0)

        // Compute speed
        let speedGbps: Int
        if linkSpeed == 4 { speedGbps = linkWidth >= 2 ? 40 : 20 }
        else if linkSpeed == 8 { speedGbps = linkWidth >= 2 ? 80 : 40 }
        else { speedGbps = max(linkSpeed * 10, 40) }
        let speedString = isConnected ? "\(speedGbps) Gb/s" : "Up to \(speedGbps) Gb/s"

        // Detect mode
        let mode: TBDevice.TBMode
        if linkSpeed >= 8 { mode = .usb4 }
        else if linkSpeed == 4 && linkWidth >= 2 { mode = .thunderbolt4 }
        else if linkSpeed == 4 { mode = .thunderbolt3 }
        else { mode = .unknown }

        // Step 5: Walk grandchildren for device info
        var deviceName = ""
        var vendor = ""
        var gcIter: io_iterator_t = IO_OBJECT_NULL
        if IORegistryEntryGetChildIterator(userPort, kIOServicePlane, &gcIter) == KERN_SUCCESS {
            defer { IOObjectRelease(gcIter) }
            var gc = IOIteratorNext(gcIter)
            while gc != IO_OBJECT_NULL {
                var gcProps: Unmanaged<CFMutableDictionary>? = nil
                IORegistryEntryCreateCFProperties(gc, &gcProps, kCFAllocatorDefault, 0)
                if let gcp = gcProps?.takeRetainedValue() as? [String: Any] {
                    deviceName = (gcp["Model"] as? String)
                               ?? (gcp["product-description"] as? String)
                               ?? (gcp["IORegistryEntryName"] as? String)
                               ?? deviceName
                    vendor = (gcp["Vendor Name"] as? String)
                           ?? (gcp["vendor-name"] as? String)
                           ?? vendor
                }
                IOObjectRelease(gc)
                gc = IOIteratorNext(gcIter)
            }
        }

        return TBDevice(
            id: "tb_\(portIndex)",
            portNumber: portIndex + 1,  // P1-P6
            linkSpeed: speedString,
            isConnected: isConnected,
            connectedDevice: deviceName,
            vendor: vendor,
            mode: mode
        )
    }

    /// Finds the first child of `parent` whose properties satisfy `predicate`.
    private func findFirstChild(
        of parent: io_service_t,
        matching predicate: (io_service_t, [String: Any]) -> Bool
    ) -> io_service_t? {
        var childIter: io_iterator_t = IO_OBJECT_NULL
        guard IORegistryEntryGetChildIterator(parent, kIOServicePlane, &childIter) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(childIter) }

        var child = IOIteratorNext(childIter)
        while child != IO_OBJECT_NULL {
            var cProps: Unmanaged<CFMutableDictionary>? = nil
            IORegistryEntryCreateCFProperties(child, &cProps, kCFAllocatorDefault, 0)
            if let cp = cProps?.takeRetainedValue() as? [String: Any], predicate(child, cp) {
                return child  // Caller must release
            }
            IOObjectRelease(child)
            child = IOIteratorNext(childIter)
        }
        return nil
    }

    // MARK: - USB via IOKit
    func collectUSB() -> [USBDevice] {
        // IOUSBHostDevice is the correct class on macOS 11+.
        // Also check IOUSBDevice for any legacy devices still on old stack.
        var devices: [USBDevice] = []
        var seen = Set<String>()

        for className in ["IOUSBHostDevice", "IOUSBDevice"] {
            let match = IOServiceMatching(className) as CFDictionary
            var iterator: io_iterator_t = IO_OBJECT_NULL
            guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS else {
                continue
            }
            defer { IOObjectRelease(iterator) }

            var service = IOIteratorNext(iterator)
            while service != IO_OBJECT_NULL {
                // NOTE: Do NOT use defer { IOObjectRelease(service) } here.
                // defer fires AFTER service = IOIteratorNext(...), releasing the NEXT
                // device's reference and corrupting the iterator. Release manually instead.
                var props: Unmanaged<CFMutableDictionary>? = nil
                IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0)

                if let p = props?.takeRetainedValue() as? [String: Any] {
                    let name   = (p["USB Product Name"] as? String)
                              ?? (p["kUSBProductString"] as? String)
                              ?? (p["IORegistryEntryName"] as? String)
                              ?? "USB Device"
                    let vendor = (p["USB Vendor Name"] as? String) ?? ""
                    let speed  = USBSpeed(rawValue: (p["Device Speed"] as? Int) ?? 0)
                    let vid    = (p["idVendor"]  as? Int) ?? 0
                    let pid    = (p["idProduct"] as? Int) ?? 0
                    let id     = "\(vid):\(pid):\(name)"

                    let hubChipVendors: Set<String> = ["Apple", "Apple Inc.",
                                                        "Fresco Logic, Inc.", "GenesysLogic",
                                                        "VIA Labs, Inc."]
                    let isGenericHub = name.contains("Hub") && hubChipVendors.contains(vendor)

                    if !isGenericHub, seen.insert(id).inserted {
                        devices.append(USBDevice(id: id, name: name, vendor: vendor,
                                                 speed: speed, vendorID: vid, productID: pid))
                    }
                }

                // Release CURRENT service before advancing to next
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
        }
        return devices.sorted { $0.name < $1.name }
    }

    // MARK: - Combined (async to allow WiFi/BT MainActor hops)
    // Note: midiDevices are collected separately by MIDICollector at 200ms cadence.
    func collect() async -> ConnSnapshot {
        let wifi = await collectWiFi()
        let bt   = await collectBluetooth()
        let tb   = collectThunderbolt()
        let usb  = collectUSB()
        return ConnSnapshot(wifi: wifi, bluetoothDevices: bt,
                            thunderboltDevices: tb, usbDevices: usb,
                            midiDevices: [])
    }
}
