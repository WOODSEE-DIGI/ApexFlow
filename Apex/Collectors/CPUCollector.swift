import Darwin
import Foundation

actor CPUCollector {
    private var previousTotals: [UInt32] = []
    private var previousIdles: [UInt32] = []
    private let cpuName: String = CPUCollector.fetchCPUName()

    func collect() -> CPUSnapshot {
        var cpuCount: natural_t = 0
        var infoCount: mach_msg_type_number_t = 0
        var infoPtr: processor_info_array_t? = nil

        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                   &cpuCount, &infoPtr, &infoCount) == KERN_SUCCESS,
              let info = infoPtr else {
            return CPUSnapshot(coreUsages: [], totalUsage: 0, loadAvg: (0, 0, 0),
                               uptime: 0, temperature: nil, cpuName: cpuName, timestamp: .now)
        }

        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: info),
                          vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.size))
        }

        let count = Int(cpuCount)
        var coreUsages: [Double] = Array(repeating: 0, count: count)

        info.withMemoryRebound(to: processor_cpu_load_info_data_t.self, capacity: count) { ptr in
            let cores = UnsafeBufferPointer(start: ptr, count: count)

            if previousTotals.count != count {
                previousTotals = Array(repeating: 0, count: count)
                previousIdles  = Array(repeating: 0, count: count)
            }

            for i in 0..<count {
                let c = cores[i]
                let user   = c.cpu_ticks.0
                let system = c.cpu_ticks.1
                let idle   = c.cpu_ticks.2
                let nice   = c.cpu_ticks.3
                let total  = user &+ system &+ idle &+ nice

                let dTotal = total &- previousTotals[i]
                let dIdle  = idle  &- previousIdles[i]
                coreUsages[i] = dTotal > 0 ? Double(dTotal - dIdle) / Double(dTotal) : 0

                previousTotals[i] = total
                previousIdles[i]  = idle
            }
        }

        let totalUsage = coreUsages.isEmpty ? 0 : coreUsages.reduce(0, +) / Double(coreUsages.count)

        // Load averages
        var loads = [Double](repeating: 0, count: 3)
        getloadavg(&loads, 3)

        return CPUSnapshot(
            coreUsages: coreUsages,
            totalUsage: totalUsage,
            loadAvg: (loads[0], loads[1], loads[2]),
            uptime: systemUptime(),
            temperature: nil,  // SMC temperature added in future
            cpuName: cpuName,
            timestamp: .now
        )
    }

    private func systemUptime() -> TimeInterval {
        var ts = timeval()
        var len = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        sysctl(&mib, 2, &ts, &len, nil, 0)
        return Date().timeIntervalSince1970 - Double(ts.tv_sec)
    }

    private static func fetchCPUName() -> String {
        var buf = [CChar](repeating: 0, count: 512)
        var size = buf.count
        sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0)
        return buf.withUnsafeBufferPointer { ptr -> String in
            guard let baseAddress = ptr.baseAddress else { return "" }
            return String(cString: baseAddress)
        }
            .replacingOccurrences(of: "(R)", with: "")
            .replacingOccurrences(of: "(TM)", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
