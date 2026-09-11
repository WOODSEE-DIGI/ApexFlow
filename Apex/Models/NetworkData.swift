import Foundation
import Observation

struct NetworkSnapshot: Sendable {
    let interfaces: [InterfaceSnapshot]
    let timestamp: Date
}

struct InterfaceSnapshot: Sendable {
    let name: String
    let ipv4: String
    let downloadRate: Double  // bytes/sec
    let uploadRate: Double
    let totalDownload: UInt64
    let totalUpload: UInt64
    let isConnected: Bool
}

struct InterfaceInfo: Identifiable {
    let id: String  // interface name
    var ipv4: String = ""
    var downloadRate: Double = 0
    var uploadRate: Double = 0
    var totalDownload: UInt64 = 0
    var totalUpload: UInt64 = 0
    var isConnected: Bool = false
    var downloadHistory: [DataPoint] = []
    var uploadHistory: [DataPoint] = []

    static let historyLength = 120

    var peakRate: Double {
        max(
            downloadHistory.map(\.value).max() ?? 1,
            uploadHistory.map(\.value).max() ?? 1,
            10_240  // floor at 10 KB/s
        )
    }

    mutating func update(from snap: InterfaceSnapshot, timestamp: Date) {
        ipv4 = snap.ipv4
        downloadRate = snap.downloadRate
        uploadRate = snap.uploadRate
        totalDownload = snap.totalDownload
        totalUpload = snap.totalUpload
        isConnected = snap.isConnected
        downloadHistory.append(DataPoint(time: timestamp, value: snap.downloadRate))
        uploadHistory.append(DataPoint(time: timestamp, value: snap.uploadRate))
        if downloadHistory.count > Self.historyLength { downloadHistory.removeFirst() }
        if uploadHistory.count > Self.historyLength { uploadHistory.removeFirst() }
    }
}

@Observable
@MainActor
final class NetworkData {
    var interfaces: [InterfaceInfo] = []
    var selectedInterface: String = ""

    func update(from snapshot: NetworkSnapshot) {
        var updated: [InterfaceInfo] = []
        for snap in snapshot.interfaces {
            if var existing = interfaces.first(where: { $0.id == snap.name }) {
                existing.update(from: snap, timestamp: snapshot.timestamp)
                updated.append(existing)
            } else {
                var new = InterfaceInfo(id: snap.name)
                new.update(from: snap, timestamp: snapshot.timestamp)
                updated.append(new)
            }
        }
        interfaces = updated
        if selectedInterface.isEmpty || !interfaces.contains(where: { $0.id == selectedInterface }) {
            selectedInterface = interfaces.first(where: { $0.isConnected })?.id ?? interfaces.first?.id ?? ""
        }
    }
}

extension Double {
    var formattedRate: String {
        let mb = self / 1_048_576
        let kb = self / 1024
        if mb >= 1 { return String(format: "%.1f MB/s", mb) }
        if kb >= 1 { return String(format: "%.0f KB/s", kb) }
        return String(format: "%.0f B/s", self)
    }
}
