import Foundation

// MARK: - Threat Assessment
/// A single resource-hogging process detected by the system-wide threat monitor.
struct ThreatAssessment: Identifiable, Hashable {
    let id = UUID()
    let pid: Int32
    let name: String
    let reason: ThreatReason
    let cpuPercent: Double
    let memoryBytes: UInt64
    let totalSystemMemoryBytes: UInt64
    let timestamp: Date

    /// Memory as a percentage of total system RAM.
    var memoryPercent: Double {
        guard totalSystemMemoryBytes > 0 else { return 0 }
        return (Double(memoryBytes) / Double(totalSystemMemoryBytes)) * 100.0
    }

    var formattedMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryBytes), countStyle: .memory)
    }
}

enum ThreatReason: String, CaseIterable {
    case memoryHog = "MEMORY HOG"
    case cpuHog = "CPU HOG"
    case memoryLeak = "RUNAWAY MEMORY LEAK"
    case systemPressure = "SYSTEM MEMORY PRESSURE"
}
