import Foundation
import Observation

struct MemorySnapshot: Sendable {
    let totalBytes: UInt64
    let usedBytes: UInt64
    let cachedBytes: UInt64
    let availableBytes: UInt64
    let swapTotal: UInt64
    let swapUsed: UInt64
    let timestamp: Date
}

@Observable
@MainActor
final class MemoryData {
    var totalBytes: UInt64 = 0
    var usedBytes: UInt64 = 0
    var cachedBytes: UInt64 = 0
    var availableBytes: UInt64 = 0
    var swapTotal: UInt64 = 0
    var swapUsed: UInt64 = 0
    var usedHistory: [DataPoint] = []

    static let historyLength = 120

    func update(from snapshot: MemorySnapshot) {
        totalBytes = snapshot.totalBytes
        usedBytes = snapshot.usedBytes
        cachedBytes = snapshot.cachedBytes
        availableBytes = snapshot.availableBytes
        swapTotal = snapshot.swapTotal
        swapUsed = snapshot.swapUsed

        let usedFraction = totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0
        usedHistory.append(DataPoint(time: snapshot.timestamp, value: usedFraction))
        if usedHistory.count > Self.historyLength {
            usedHistory.removeFirst(usedHistory.count - Self.historyLength)
        }
    }

    var usedFraction: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0 }
    var cachedFraction: Double { totalBytes > 0 ? Double(cachedBytes) / Double(totalBytes) : 0 }
    var swapFraction: Double { swapTotal > 0 ? Double(swapUsed) / Double(swapTotal) : 0 }
}

// MARK: - Formatting helpers
extension UInt64 {
    var formattedBytes: String {
        let gb = Double(self) / 1_073_741_824
        let mb = Double(self) / 1_048_576
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        if mb >= 1 { return String(format: "%.0f MB", mb) }
        return String(format: "%.0f KB", Double(self) / 1024)
    }
}
