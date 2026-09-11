import Foundation
import Observation

struct DiskSnapshot: Sendable {
    let mountpoint: String
    let name: String
    let totalBytes: UInt64
    let usedBytes: UInt64
    let freeBytes: UInt64
    let readRate: Double    // bytes/sec
    let writeRate: Double
    let timestamp: Date
}

struct DiskInfo: Identifiable {
    let id: String  // mountpoint
    var name: String
    var mountpoint: String
    var totalBytes: UInt64 = 0
    var usedBytes: UInt64 = 0
    var freeBytes: UInt64 = 0
    var readRate: Double = 0
    var writeRate: Double = 0
    var readHistory: [DataPoint] = []
    var writeHistory: [DataPoint] = []

    // S.M.A.R.T. / diskutil health snapshot (refreshed periodically)
    var health: DiskHealth?
    var healthWarnReplace: Bool = false

    static let historyLength = 60

    var usedFraction: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0 }

    mutating func update(from snapshot: DiskSnapshot) {
        totalBytes = snapshot.totalBytes
        usedBytes = snapshot.usedBytes
        freeBytes = snapshot.freeBytes
        readRate = snapshot.readRate
        writeRate = snapshot.writeRate

        readHistory.append(DataPoint(time: snapshot.timestamp, value: snapshot.readRate))
        writeHistory.append(DataPoint(time: snapshot.timestamp, value: snapshot.writeRate))
        if readHistory.count > Self.historyLength { readHistory.removeFirst() }
        if writeHistory.count > Self.historyLength { writeHistory.removeFirst() }
    }

    var peakRate: Double {
        max(
            readHistory.map(\.value).max() ?? 1,
            writeHistory.map(\.value).max() ?? 1,
            1_048_576  // floor at 1 MB/s
        )
    }
}

@Observable
@MainActor
final class DiskData {
    var disks: [DiskInfo] = []

    func update(from snapshots: [DiskSnapshot]) {
        var updated: [DiskInfo] = []
        for snap in snapshots {
            if var existing = disks.first(where: { $0.id == snap.mountpoint }) {
                existing.update(from: snap)
                updated.append(existing)
            } else {
                var new = DiskInfo(id: snap.mountpoint, name: snap.name, mountpoint: snap.mountpoint)
                new.update(from: snap)
                updated.append(new)
            }
        }
        disks = updated
    }

    func update(health: DiskHealth, for mountpoint: String) {
        guard let index = disks.firstIndex(where: { $0.id == mountpoint }) else { return }
        disks[index].health = health
        disks[index].healthWarnReplace = health.recommendsReplacement
    }
}
