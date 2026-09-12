import Darwin
import Foundation
import IOKit

actor DiskCollector {
    private var previousBytesRead:    [String: UInt64] = [:]
    private var previousBytesWritten: [String: UInt64] = [:]
    private var previousTime: Date = .now

    /// Same exclude-filter logic as patched btop, plus Apple cryptex / MobileAsset volumes
    private let excludePrefixes = [
        "/System/Volumes/",
        "/Library/Developer/",
        "/Volumes/.timemachine/",
        "/Volumes/com.apple.TimeMachine.localsnapshots/",
        "/private/var/run/com.apple.security.cryptexd/"
    ]

    /// Names that are clearly Apple internal volumes, not user drives.
    private let excludeNamePrefixes = ["com.apple."]

    /// Hide tiny transient volumes (e.g. temporary DMGs created during app builds).
    private let minimumVolumeBytes: UInt64 = 100_000_000  // 100 MB

    func collect() -> [DiskSnapshot] {
        let now = Date()
        let elapsed = now.timeIntervalSince(previousTime)
        previousTime = now

        var stfs: UnsafeMutablePointer<statfs>? = nil
        let count = getmntinfo(&stfs, MNT_NOWAIT)
        guard count > 0, let mounts = stfs else { return [] }

        // Build IOKit read/write map: device -> (bytesRead, bytesWritten)
        let ioMap = collectDiskIO()

        var snapshots: [DiskSnapshot] = []

        for i in 0..<Int(count) {
            let m = mounts[i]
            let mountpoint = withUnsafeBytes(of: m.f_mntonname) { raw in
                String(bytes: raw.prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""
            }
            let fstype = withUnsafeBytes(of: m.f_fstypename) { raw in
                String(bytes: raw.prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""
            }
            let device = withUnsafeBytes(of: m.f_mntfromname) { raw in
                String(bytes: raw.prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""
            }

            let name = mountpoint == "/" ? "Macintosh HD"
                       : String(mountpoint.split(separator: "/").last ?? Substring(mountpoint))

            // Skip autofs and pseudo filesystems
            if fstype == "autofs" || fstype == "devfs" || fstype == "kernfs" { continue }
            // Apply exclude filter
            if excludePrefixes.contains(where: { mountpoint.hasPrefix($0) }) { continue }
            if excludeNamePrefixes.contains(where: { name.hasPrefix($0) }) { continue }

            var vfs = statvfs()
            guard statvfs(mountpoint, &vfs) == 0, vfs.f_blocks > 0 else { continue }

            let blockSize = UInt64(vfs.f_frsize)
            let total = UInt64(vfs.f_blocks) * blockSize
            let free  = UInt64(vfs.f_bfree)  * blockSize
            let used  = total - free

            // Drop tiny transient volumes (temp DMGs, installers, etc.).
            if total < minimumVolumeBytes { continue }

            // I/O rates
            var readRate = 0.0, writeRate = 0.0
            let transport = ioMap[device]?.transport ?? .unknown
            if let info = ioMap[device], elapsed > 0 {
                let prevR = previousBytesRead[device] ?? info.readBytes
                let prevW = previousBytesWritten[device] ?? info.writeBytes
                readRate  = max(0, Double(info.readBytes  - prevR) / elapsed)
                writeRate = max(0, Double(info.writeBytes - prevW) / elapsed)
                previousBytesRead[device]    = info.readBytes
                previousBytesWritten[device] = info.writeBytes
            }

            snapshots.append(DiskSnapshot(
                mountpoint: mountpoint,
                name: name,
                totalBytes: total,
                usedBytes: used,
                freeBytes: free,
                readRate: readRate,
                writeRate: writeRate,
                transport: transport,
                timestamp: now
            ))
        }

        return snapshots
    }

    // MARK: - IOKit I/O stats
    private struct DiskIOInfo {
        let readBytes: UInt64
        let writeBytes: UInt64
        let transport: DiskTransport
    }

    private func collectDiskIO() -> [String: DiskIOInfo] {
        var result: [String: DiskIOInfo] = [:]

        let matchDict = IOServiceMatching("IOMediaBSDClient")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator) == KERN_SUCCESS else {
            return result
        }
        defer { IOObjectRelease(iterator) }

        // NOTE: Do NOT use defer { IOObjectRelease(service) } inside this loop.
        // defer fires AFTER service = IOIteratorNext(...), releasing the NEXT service.
        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            var parent: io_registry_entry_t = IO_OBJECT_NULL
            IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent)

            if parent != IO_OBJECT_NULL {
                defer { IOObjectRelease(parent) }

                // Get BSD name
                let bsdKey = "BSD Name" as CFString
                if let bsdRef = IORegistryEntryCreateCFProperty(parent, bsdKey, kCFAllocatorDefault, 0),
                   let bsdName = bsdRef.takeRetainedValue() as? String {

                    let device = "/dev/" + bsdName
                    var props: Unmanaged<CFMutableDictionary>? = nil
                    IORegistryEntryCreateCFProperties(parent, &props, kCFAllocatorDefault, 0)
                    if let p = props?.takeRetainedValue() as? [String: Any],
                       let stats = p["Statistics"] as? [String: Any] {
                        let read  = (stats["Bytes read from block device"]  as? UInt64) ?? 0
                        let write = (stats["Bytes written to block device"] as? UInt64) ?? 0
                        let transport = transportFor(media: parent)
                        result[device] = DiskIOInfo(readBytes: read, writeBytes: write, transport: transport)
                    }
                }
            }

            // Release CURRENT service before advancing
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return result
    }

    /// Walk the IOService tree from a media object up to find Thunderbolt or USB ancestry.
    private func transportFor(media: io_registry_entry_t) -> DiskTransport {
        var entry = media
        // `media` itself is owned by the caller; do not release it.
        // Cap the walk depth to avoid infinite loops in the unlikely case of a registry cycle.
        for _ in 0..<64 {
            var parent: io_registry_entry_t = IO_OBJECT_NULL
            let kr = IORegistryEntryGetParentEntry(entry, kIOServicePlane, &parent)

            // Release duplicated entries (anything other than the original `media`).
            let releasingEntry = entry != media
            defer { if releasingEntry { IOObjectRelease(entry) } }

            guard kr == KERN_SUCCESS, parent != IO_OBJECT_NULL else { return .unknown }

            if let cls = className(of: parent) {
                if cls == "IOThunderboltController" {
                    var id: UInt64 = 0
                    IORegistryEntryGetRegistryEntryID(parent, &id)
                    IOObjectRelease(parent)
                    return .thunderbolt(controllerID: id)
                }
                if cls == "IOUSBHostDevice" || cls == "IOUSBDevice" {
                    var id: UInt64 = 0
                    IORegistryEntryGetRegistryEntryID(parent, &id)
                    IOObjectRelease(parent)
                    return .usb(registryID: id)
                }
            }

            entry = parent
        }
        return .unknown
    }

    private func className(of entry: io_registry_entry_t) -> String? {
        // IOObjectCopyClass returns a retained CFString, avoiding the unsafe pointer dance
        // that triggered a runtime unsafeBitCast failure in optimized Release builds.
        guard let unmanaged = IOObjectCopyClass(entry) else { return nil }
        return unmanaged.takeRetainedValue() as String
    }
}
