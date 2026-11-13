import Foundation
import Darwin.Mach

// MARK: - App Health Watchdog
/// Monitors ApexFlow's own CPU and memory usage. If the app enters a runaway
/// state (high sustained CPU, excessive memory growth, or repeated rapid sample
/// loops) it triggers a full-screen emergency warning so the user can kill the
/// process before the system watchdog has to step in.
@MainActor
final class AppHealthWatchdog {
    static let shared = AppHealthWatchdog()

    // MARK: - Thresholds

    /// CPU percentage (0...100+) averaged over the sample window.
    let cpuThreshold: Double = 80.0
    /// How many consecutive samples must exceed the threshold before warning.
    let consecutiveSamplesThreshold = 6
    /// Memory threshold in bytes (2 GB). Raised for workstations with large
    /// unified memory pools (e.g., 128 GB); a monitor app can legitimately
    /// cache several hundred MB of process/socket data without being runaway.
    let memoryThreshold: UInt64 = 2 * 1024 * 1024 * 1024
    /// Sample interval in seconds.
    let sampleInterval: TimeInterval = 2.0

    // MARK: - State

    private var timer: Timer?
    private var previousCPU: Double = 0
    private var previousSampleTime: Date?
    private var consecutiveHighCPU = 0
    private var warningShown = false

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard timer == nil else { return }
        previousSampleTime = Date()
        previousCPU = currentTotalCPUTime()

        timer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sample()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Sampling

    private func sample() {
        guard !warningShown else { return }

        let now = Date()
        let currentCPU = currentTotalCPUTime()
        let residentMemory = currentResidentMemory()

        defer {
            previousSampleTime = now
            previousCPU = currentCPU
        }

        guard let previousSampleTime else { return }
        let elapsed = now.timeIntervalSince(previousSampleTime)
        guard elapsed > 0 else { return }

        let cpuDelta = max(0, currentCPU - previousCPU)
        let cpuPercent = (cpuDelta / elapsed) * 100.0

        // Memory breach is immediate.
        if residentMemory > memoryThreshold {
            triggerWarning(
                reason: .memoryBreach,
                detail: "ApexFlow is using \(byteString(residentMemory)) of memory."
            )
            return
        }

        // CPU breach requires several consecutive samples to avoid false alarms
        // from brief spikes (e.g., building a chart).
        if cpuPercent > cpuThreshold {
            consecutiveHighCPU += 1
            if consecutiveHighCPU >= consecutiveSamplesThreshold {
                triggerWarning(
                    reason: .runawayCPU,
                    detail: "ApexFlow has used \(Int(cpuPercent))% CPU for the last \(consecutiveHighCPU * Int(sampleInterval)) seconds."
                )
                return
            }
        } else {
            consecutiveHighCPU = 0
        }
    }

    // MARK: - Triggers

    private func triggerWarning(reason: EmergencyReason, detail: String) {
        warningShown = true
        stop()
        EmergencyWarningManager.shared.present(
            reason: reason,
            detail: detail,
            targetPID: getpid()
        )
    }

    // MARK: - Helpers

    /// Total CPU time (user + system) in seconds for this process.
    private func currentTotalCPUTime() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return
            Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000.0 +
            Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000.0
    }

    /// Resident set size in bytes.
    private func currentResidentMemory() -> UInt64 {
        var info = task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutableBytes(of: &info) { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return KERN_FAILURE }
            let intPtr = baseAddress.assumingMemoryBound(to: integer_t.self)
            return task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), intPtr, &count)
        }
        guard kr == KERN_SUCCESS else { return 0 }
        return UInt64(info.resident_size)
    }

    private func byteString(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

enum EmergencyReason: String {
    case runawayCPU = "Runaway CPU Usage"
    case memoryBreach = "Memory Limit Exceeded"
    case manualTrigger = "Manual Kill Switch"
}
