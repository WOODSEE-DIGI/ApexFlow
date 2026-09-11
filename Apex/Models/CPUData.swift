import Foundation
import Observation

struct CPUSnapshot: Sendable {
    let coreUsages: [Double]      // 0.0–1.0 per core
    let totalUsage: Double         // 0.0–1.0
    let loadAvg: (Double, Double, Double)
    let uptime: TimeInterval
    let temperature: Double?       // Celsius, nil if unavailable
    let cpuName: String
    let timestamp: Date
}

struct DataPoint: Identifiable, Sendable {
    let id: UUID
    let time: Date
    let value: Double

    init(time: Date = .now, value: Double) {
        self.id = UUID()
        self.time = time
        self.value = value
    }
}

@Observable
@MainActor
final class CPUData {
    var coreUsages: [Double] = []
    var totalUsage: Double = 0
    var history: [DataPoint] = []
    var loadAvg: (Double, Double, Double) = (0, 0, 0)
    var uptime: TimeInterval = 0
    var temperature: Double? = nil
    var cpuName: String = ""

    static let historyLength = 120

    func update(from snapshot: CPUSnapshot) {
        coreUsages = snapshot.coreUsages
        totalUsage = snapshot.totalUsage
        loadAvg = snapshot.loadAvg
        uptime = snapshot.uptime
        temperature = snapshot.temperature
        if cpuName.isEmpty { cpuName = snapshot.cpuName }

        history.append(DataPoint(time: snapshot.timestamp, value: snapshot.totalUsage))
        if history.count > Self.historyLength {
            history.removeFirst(history.count - Self.historyLength)
        }
    }

    var formattedUptime: String {
        let d = Int(uptime) / 86400
        let h = (Int(uptime) % 86400) / 3600
        let m = (Int(uptime) % 3600) / 60
        if d > 0 { return "\(d)d \(h)h \(m)m" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
