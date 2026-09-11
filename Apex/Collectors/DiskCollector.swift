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
        "/private/var/run/com.apple.security.cryptexd/"
    ]

    /// Names that are clearly Apple internal volumes, not user drives.
    private let excludeNamePrefixes = ["com.apple."]

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

            // I/O rates
            var readRate = 0.0, writeRate = 0.0
            if let (curRead, curWrite) = ioMap[device], elapsed > 0 {
                let prevR = previousBytesRead[device] ?? curRead
                let prevW = previousBytesWritten[device] ?? curWrite
                readRate  = max(0, Double(curRead  - prevR) / elapsed)
                writeRate = max(0, Double(curWrite - prevW) / elapsed)
                previousBytesRead[device]    = curRead
                previousBytesWritten[device] = curWrite
            }

            snapshots.append(DiskSnapshot(
                mountpoint: mountpoint,
                name: name,
                totalBytes: total,
                usedBytes: used,
                freeBytes: free,
                readRate: readRate,
                writeRate: writeRate,
                timestamp: now
            ))
        }

        return snapshots
    }

    // MARK: - IOKit I/O stats
    private func collectDiskIO() -> [String: (UInt64, UInt64)] {
        var result: [String: (UInt64, UInt64)] = [:]

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
                        result[device] = (read, write)
                    }
                }
                IOObjectRelease(parent)
            }

            // Release CURRENT service before advancing
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return result
    }
}
