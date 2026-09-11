import Darwin
import Foundation

actor MemoryCollector {
    func collect() -> MemorySnapshot {
        var vmStats = vm_statistics64_data_t()
        var vmCount = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<UInt32>.size
        )

        _ = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &vmCount)
            }
        }

        let pageSize = UInt64(getpagesize())
        let free      = UInt64(vmStats.free_count) * pageSize
        let active    = UInt64(vmStats.active_count) * pageSize
        let wired     = UInt64(vmStats.wire_count) * pageSize
        let cached    = UInt64(vmStats.external_page_count) * pageSize
        let used      = active + wired

        var totalMem: Int64 = 0
        var size = MemoryLayout<Int64>.size
        sysctlbyname("hw.memsize", &totalMem, &size, nil, 0)
        let total = UInt64(totalMem)

        // Swap
        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        var swapMib: [Int32] = [CTL_VM, VM_SWAPUSAGE]
        sysctl(&swapMib, 2, &swapUsage, &swapSize, nil, 0)

        return MemorySnapshot(
            totalBytes:     total,
            usedBytes:      min(used, total),
            cachedBytes:    cached,
            availableBytes: free,
            swapTotal:      swapUsage.xsu_total,
            swapUsed:       swapUsage.xsu_used,
            timestamp:      .now
        )
    }
}
