import Foundation

// MARK: - Threat Assessment
/// A single threat detected by the system-wide threat monitor: either a
/// resource-hogging process or a suspicious outbound WAN connection.
struct ThreatAssessment: Identifiable, Hashable {
    let id = UUID()
    let pid: Int32
    let name: String
    let reason: ThreatReason
    let cpuPercent: Double
    let memoryBytes: UInt64
    let totalSystemMemoryBytes: UInt64
    let timestamp: Date

    // MARK: - WAN leak details (set only when reason == .wanLeak)
    let wanRisk: WANAlertRisk?
    let remoteEndpoint: String?
    let wanAdvice: String?
    let alertID: String?
    let bundleID: String?
    let commandLine: String?

    init(
        pid: Int32,
        name: String,
        reason: ThreatReason,
        cpuPercent: Double = 0,
        memoryBytes: UInt64 = 0,
        totalSystemMemoryBytes: UInt64 = 0,
        timestamp: Date = Date(),
        wanRisk: WANAlertRisk? = nil,
        remoteEndpoint: String? = nil,
        wanAdvice: String? = nil,
        alertID: String? = nil,
        bundleID: String? = nil,
        commandLine: String? = nil
    ) {
        self.pid = pid
        self.name = name
        self.reason = reason
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
        self.totalSystemMemoryBytes = totalSystemMemoryBytes
        self.timestamp = timestamp
        self.wanRisk = wanRisk
        self.remoteEndpoint = remoteEndpoint
        self.wanAdvice = wanAdvice
        self.alertID = alertID
        self.bundleID = bundleID
        self.commandLine = commandLine
    }

    /// Memory as a percentage of total system RAM.
    var memoryPercent: Double {
        guard totalSystemMemoryBytes > 0 else { return 0 }
        return (Double(memoryBytes) / Double(totalSystemMemoryBytes)) * 100.0
    }

    var formattedMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryBytes), countStyle: .memory)
    }

    var isWANLeak: Bool {
        reason == .wanLeak
    }
}

enum ThreatReason: String, CaseIterable {
    case memoryHog = "MEMORY HOG"
    case cpuHog = "CPU HOG"
    case memoryLeak = "RUNAWAY MEMORY LEAK"
    case systemPressure = "SYSTEM MEMORY PRESSURE"
    case wanLeak = "WAN LEAK"
}
