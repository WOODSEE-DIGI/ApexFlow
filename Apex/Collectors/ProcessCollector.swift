import Darwin
import Foundation

actor ProcessCollector {
    private var previousCPUTimes: [Int32: UInt64] = [:]
    private var previousTotalTicks: UInt64 = 0
    private var previousTime: Date = .now

    func collect() -> [ProcessSnapshot] {
        let now = Date()
        let elapsed = now.timeIntervalSince(previousTime)
        previousTime = now

        // Get CPU total ticks for % calculation
        let currentTotalTicks = totalCPUTicks()
        previousTotalTicks = currentTotalTicks

        // Enumerate processes
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        sysctl(&mib, 4, nil, &size, nil, 0)
        guard size > 0 else { return [] }

        let count = size / MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        sysctl(&mib, 4, &procs, &size, nil, 0)

        var snapshots: [ProcessSnapshot] = []

        for kproc in procs {
            let pid = kproc.kp_proc.p_pid
            guard pid > 0 else { continue }

            let name = withUnsafeBytes(of: kproc.kp_proc.p_comm) { raw in
                let bytes = raw.prefix(while: { $0 != 0 })
                return String(bytes: bytes, encoding: .utf8) ?? ""
            }
            guard !name.isEmpty else { continue }

            // Get task info for memory and CPU time
            var taskInfo = proc_taskinfo()
            let infoSize = proc_pidinfo(pid, PROC_PIDTASKINFO, 0,
                                        &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))

            let memBytes: UInt64
            let cpuTime: UInt64
            let threads: Int
            if infoSize > 0 {
                memBytes = taskInfo.pti_resident_size
                cpuTime  = taskInfo.pti_total_user + taskInfo.pti_total_system
                threads  = Int(taskInfo.pti_threadnum)
            } else {
                memBytes = 0; cpuTime = 0; threads = 0
            }

            let prevCPU = previousCPUTimes[pid] ?? cpuTime
            let deltaCPU = cpuTime >= prevCPU ? cpuTime - prevCPU : 0
            previousCPUTimes[pid] = cpuTime

            // Convert mach ticks to percent using elapsed time
            // machTck ≈ 1ns on Apple Silicon
            let cpuPercent: Double
            if elapsed > 0 && deltaCPU > 0 {
                cpuPercent = min(100 * Double(deltaCPU) / (elapsed * 1_000_000_000), 100)
            } else {
                cpuPercent = 0
            }

            let uid = kproc.kp_eproc.e_ucred.cr_uid
            let user: String
            if let pw = getpwuid(uid) {
                user = String(cString: pw.pointee.pw_name)
            } else {
                user = String(uid)
            }

            let statusChar = kproc.kp_proc.p_stat
            let status: String
            switch Int32(statusChar) {
            case SRUN:   status = "Run"
            case SSLEEP: status = "Sleep"
            case SIDL:   status = "Idle"
            case SSTOP:  status = "Stop"
            case SZOMB:  status = "Zombie"
            default:     status = "?"
            }

            snapshots.append(ProcessSnapshot(
                id: pid,
                ppid: kproc.kp_eproc.e_ppid,
                name: name,
                user: user,
                cpuPercent: cpuPercent,
                memoryBytes: memBytes,
                threads: threads,
                status: status,
                isAI: false,
                aiRole: nil
            ))
        }

        // Clean up stale PID entries
        let activePIDs = Set(snapshots.map(\.id))
        previousCPUTimes = previousCPUTimes.filter { activePIDs.contains($0.key) }

        return snapshots
    }

    private func totalCPUTicks() -> UInt64 {
        var cpuCount: natural_t = 0
        var infoCount: mach_msg_type_number_t = 0
        var infoPtr: processor_info_array_t? = nil
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                   &cpuCount, &infoPtr, &infoCount) == KERN_SUCCESS,
              let info = infoPtr else { return 0 }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: info),
                          vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.size))
        }
        var total: UInt64 = 0
        info.withMemoryRebound(to: processor_cpu_load_info_data_t.self, capacity: Int(cpuCount)) { ptr in
            let cores = UnsafeBufferPointer(start: ptr, count: Int(cpuCount))
            for c in cores {
                total += UInt64(c.cpu_ticks.0) + UInt64(c.cpu_ticks.1) +
                         UInt64(c.cpu_ticks.2) + UInt64(c.cpu_ticks.3)
            }
        }
        return total
    }
}
