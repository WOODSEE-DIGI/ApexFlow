import Foundation
import AppKit
import Darwin.Mach

// MARK: - System Threat Monitor
/// Scans system-wide CPU and memory usage and triggers a dramatic full-screen
/// warning when a background process is hogging resources or the system is
/// under severe memory pressure.
@MainActor
final class SystemThreatMonitor {
    static let shared = SystemThreatMonitor()

    // MARK: - Thresholds

    /// Minimum process memory (as % of total RAM) to flag as a memory hog.
    /// For a 128 GB machine, 15% ≈ 19 GB.
    let memoryHogThresholdPercent: Double = 15.0
    /// Minimum CPU% for a background process to be flagged as a CPU hog.
    let cpuHogThresholdPercent: Double = 50.0
    /// System-wide memory pressure: warn when used memory exceeds this %.
    let systemPressureThresholdPercent: Double = 85.0
    /// Sample interval.
    let sampleInterval: TimeInterval = 5.0

    // MARK: - State

    private var timer: Timer?
    private var seenThreats: [String: Int] = [:]
    private var seenWANLeaks: [String: Int] = [:]
    private var warningPresented = false

    /// Number of consecutive samples a resource threat must appear in.
    let confirmationThreshold = 2
    /// WAN leaks are event-based (each new outbound connection is reported once),
    /// so a single report is enough to trigger the warning.
    let wanConfirmationThreshold = 1

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scan()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Scanning

    private func scan() {
        guard !warningPresented else { return }

        let totalMemory = totalSystemMemory()
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
        let processes = currentProcessList()

        var threats = [ThreatAssessment]()

        // System-wide memory pressure.
        let usedMemory = totalMemory - freeSystemMemory()
        let usedPercent = totalMemory > 0 ? (Double(usedMemory) / Double(totalMemory)) * 100.0 : 0
        if usedPercent > systemPressureThresholdPercent {
            threats.append(ThreatAssessment(
                pid: -1,
                name: "System Memory",
                reason: .systemPressure,
                cpuPercent: 0,
                memoryBytes: usedMemory,
                totalSystemMemoryBytes: totalMemory,
                timestamp: Date()
            ))
        }

        // Per-process hogs (skip frontmost app and ApexFlow itself).
        let apexPID = getpid()
        for proc in processes {
            guard proc.pid != frontmostPID && proc.pid != apexPID else { continue }

            if proc.memoryBytes > 0 && totalMemory > 0 {
                let memPercent = (Double(proc.memoryBytes) / Double(totalMemory)) * 100.0
                if memPercent >= memoryHogThresholdPercent {
                    threats.append(ThreatAssessment(
                        pid: proc.pid,
                        name: proc.name,
                        reason: .memoryHog,
                        cpuPercent: proc.cpuPercent,
                        memoryBytes: proc.memoryBytes,
                        totalSystemMemoryBytes: totalMemory,
                        timestamp: Date()
                    ))
                }
            }

            if proc.cpuPercent >= cpuHogThresholdPercent {
                threats.append(ThreatAssessment(
                    pid: proc.pid,
                    name: proc.name,
                    reason: .cpuHog,
                    cpuPercent: proc.cpuPercent,
                    memoryBytes: proc.memoryBytes,
                    totalSystemMemoryBytes: totalMemory,
                    timestamp: Date()
                ))
            }
        }

        // Dedupe by PID, combining reasons so a single process doesn't appear
        // twice as both a CPU hog and a memory hog.
        var threatByPID: [Int32: ThreatAssessment] = [:]
        for threat in threats {
            if let existing = threatByPID[threat.pid] {
                // Keep the most severe reason ordering: systemPressure, memoryHog,
                // cpuHog. For stats, keep the higher values.
                let mergedReason: ThreatReason
                switch (existing.reason, threat.reason) {
                case (.systemPressure, _), (_, .systemPressure):
                    mergedReason = .systemPressure
                case (.memoryHog, _), (_, .memoryHog):
                    mergedReason = .memoryHog
                default:
                    mergedReason = .cpuHog
                }
                threatByPID[threat.pid] = ThreatAssessment(
                    pid: threat.pid,
                    name: threat.name,
                    reason: mergedReason,
                    cpuPercent: max(existing.cpuPercent, threat.cpuPercent),
                    memoryBytes: max(existing.memoryBytes, threat.memoryBytes),
                    totalSystemMemoryBytes: threat.totalSystemMemoryBytes,
                    timestamp: threat.timestamp
                )
            } else {
                threatByPID[threat.pid] = threat
            }
        }
        let deduped = Array(threatByPID.values).sorted { $0.memoryBytes > $1.memoryBytes }

        guard !deduped.isEmpty else {
            seenThreats.removeAll()
            return
        }

        // Require threats to persist across a couple of samples to avoid
        // one-shot spikes from transient background tasks.
        let key = deduped.map { "\($0.pid):\($0.reason.rawValue)" }.sorted().joined(separator: "|")
        seenThreats[key, default: 0] += 1
        if seenThreats[key]! >= confirmationThreshold {
            presentWarning(threats: deduped)
        }
    }

    private func presentWarning(threats: [ThreatAssessment]) {
        warningPresented = true
        stop()
        NationalSecurityWarningManager.shared.present(threats: threats) { [weak self] in
            self?.warningPresented = false
            self?.seenThreats.removeAll()
            self?.seenWANLeaks.removeAll()
        }
    }

    // MARK: - WAN leak reporting

    /// Called by `NetworkLeakMonitor` when a medium/high-risk outbound WAN
    /// connection is detected. The warning uses an amber/blue theme distinct
    /// from the red system-hog theme.
    func reportWANLeak(_ threat: ThreatAssessment) {
        guard !warningPresented else { return }

        let key = "\(threat.pid)-\(threat.remoteEndpoint ?? "unknown")"
        seenWANLeaks[key, default: 0] += 1
        if seenWANLeaks[key]! >= wanConfirmationThreshold {
            presentWarning(threats: [threat])
        }
    }

    // MARK: - System memory

    private func totalSystemMemory() -> UInt64 {
        var info = host_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutableBytes(of: &info) { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return KERN_FAILURE }
            let ptr = base.assumingMemoryBound(to: integer_t.self)
            return host_info(mach_host_self(), HOST_BASIC_INFO, ptr, &count)
        }
        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.max_mem)
    }

    private func freeSystemMemory() -> UInt64 {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var stats = vm_statistics64_data_t()
        let result = withUnsafeMutableBytes(of: &stats) { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return KERN_FAILURE }
            let ptr = base.assumingMemoryBound(to: integer_t.self)
            return host_statistics64(mach_host_self(), HOST_VM_INFO64, ptr, &size)
        }
        guard result == KERN_SUCCESS else { return 0 }
        let pageSize = UInt64(getpagesize())
        let freeBytes = UInt64(stats.free_count) * pageSize
        let inactiveBytes = UInt64(stats.inactive_count) * pageSize
        return freeBytes + inactiveBytes
    }

    // MARK: - Process list

    private struct ProcessSnapshot {
        let pid: Int32
        let name: String
        let cpuPercent: Double
        let memoryBytes: UInt64
    }

    private func currentProcessList() -> [ProcessSnapshot] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-eo", "pid,pcpu,rss,args"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8) else { return [] }

        var results = [ProcessSnapshot]()
        var firstLine = true
        for line in output.components(separatedBy: .newlines) {
            if firstLine { firstLine = false; continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Parse: PID %CPU RSS ARGS...
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 4,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts[1]),
                  let rssKB = UInt64(parts[2]) else { continue }

            // Reconstruct args (everything after RSS) and extract executable basename.
            var fieldEnd = trimmed.startIndex
            var fieldCount = 0
            while fieldEnd < trimmed.endIndex && fieldCount < 3 {
                while fieldEnd < trimmed.endIndex && !trimmed[fieldEnd].isWhitespace {
                    fieldEnd = trimmed.index(after: fieldEnd)
                }
                while fieldEnd < trimmed.endIndex && trimmed[fieldEnd].isWhitespace {
                    fieldEnd = trimmed.index(after: fieldEnd)
                }
                fieldCount += 1
            }
            let commandLine = String(trimmed[fieldEnd...])
            let execName = commandLine.split(separator: " ").first.map(String.init) ?? commandLine
            let baseName = (execName as NSString).lastPathComponent

            results.append(ProcessSnapshot(
                pid: pid,
                name: baseName.isEmpty ? "pid-\(pid)" : baseName,
                cpuPercent: cpu,
                memoryBytes: rssKB * 1024
            ))
        }
        return results
    }
}
