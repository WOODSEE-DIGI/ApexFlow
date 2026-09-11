import Foundation
import SwiftUI

// MARK: - Disk health snapshot
/// A snapshot of a drive's physical health as reported by `diskutil` / `smartctl`.
/// Kept in-memory on `DiskInfo.health` and refreshed periodically by `DiskHealthService`.
struct DiskHealth: Codable, Sendable, Hashable {
    enum Status: String, Codable, Sendable, Hashable {
        case healthy, caution, failing, unknown, unsupported
    }

    var status: Status
    var smartStatus: String?
    var busProtocol: String?
    var isSSD: Bool?
    var temperatureC: Int?
    var powerOnHours: Int?
    var wearLevelPercent: Int?
    var reallocatedSectorCount: Int?
    var pendingSectorCount: Int?
    var criticalWarning: String?
    var percentageUsed: Int?
    var message: String?
    var capturedAt: Date

    // Volume / filesystem checks
    var freeSpacePercent: Int?
    var filesystemVerifyOK: Bool?
    var filesystemVerifyMessage: String?
    var fileVaultEnabled: Bool?
    var encryptionEnabled: Bool?
    var timeMachineLastBackup: Date?

    // Extra SMART / mechanical counters
    var powerCycleCount: Int?
    var startStopCount: Int?
    var loadCycleCount: Int?
    var udmaCRCErrorCount: Int?
    var offlineUncorrectable: Int?
    var gSenseErrorRate: Int?
    var multiZoneErrorCount: Int?

    /// True when the snapshot suggests the drive should be replaced soon.
    var recommendsReplacement: Bool {
        status == .failing
        || criticalWarning != nil
        || filesystemVerifyOK == false
        || (reallocatedSectorCount ?? 0) > 0
        || (pendingSectorCount ?? 0) > 0
        || (wearLevelPercent ?? 0) > 90
        || (percentageUsed ?? 0) > 90
        || (offlineUncorrectable ?? 0) > 0
        || (udmaCRCErrorCount ?? 0) > 0
    }

    /// A 0-100 score where 100 is healthiest.
    /// Drives without SMART are not penalised — unsupported just means we
    /// cannot confirm health, not that health is degraded.
    var score: Int {
        var s = 100
        switch status {
        case .healthy: break
        case .caution: s -= 25
        case .failing: s -= 75
        case .unknown: s -= 5
        case .unsupported: break
        }
        if criticalWarning != nil { s -= 40 }
        if filesystemVerifyOK == false { s -= 20 }
        if let free = freeSpacePercent, free < 10 { s -= 10 }
        if let reallocated = reallocatedSectorCount, reallocated > 0 { s -= min(30, reallocated * 5) }
        if let pending = pendingSectorCount, pending > 0 { s -= min(30, pending * 5) }
        if let offline = offlineUncorrectable, offline > 0 { s -= 30 }
        if let udma = udmaCRCErrorCount, udma > 0 { s -= 15 }
        if let wear = wearLevelPercent { s -= wear / 4 }
        if let used = percentageUsed { s -= used / 4 }
        if let temp = temperatureC, temp > 70 { s -= 10 }
        return max(0, min(100, s))
    }
}

// MARK: - Selectable health metrics

/// A selectable disk-health metric shown in the Storage Health panel.
/// The user can toggle each metric on/off; the selection is persisted
/// automatically via `DiskHealthMetricsStore`.
enum DiskHealthMetric: String, CaseIterable, Codable, Identifiable {
    case smartStatus
    case healthScore
    case freeSpace
    case filesystemVerify
    case temperature
    case powerOnHours
    case powerCycles
    case startStops
    case loadCycles
    case udmaCRCErrors
    case reallocatedSectors
    case pendingSectors
    case offlineUncorrectable
    case gSenseErrors
    case multiZoneErrors
    case wearLevel
    case percentageUsed
    case fileVault
    case encryption
    case timeMachineBackup
    case busProtocol
    case isSSD

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .smartStatus:          return "SMART status"
        case .healthScore:          return "Health score"
        case .freeSpace:            return "Free space %"
        case .filesystemVerify:     return "Filesystem verify"
        case .temperature:          return "Temperature"
        case .powerOnHours:         return "Power-on hours"
        case .powerCycles:          return "Power cycles"
        case .startStops:           return "Start/stop count"
        case .loadCycles:           return "Load cycles"
        case .udmaCRCErrors:        return "UDMA CRC errors"
        case .reallocatedSectors:   return "Reallocated sectors"
        case .pendingSectors:       return "Pending sectors"
        case .offlineUncorrectable: return "Offline uncorrectable"
        case .gSenseErrors:         return "G-sense errors"
        case .multiZoneErrors:      return "Multi-zone errors"
        case .wearLevel:            return "Wear level %"
        case .percentageUsed:       return "NVMe % used"
        case .fileVault:            return "FileVault"
        case .encryption:           return "Encryption"
        case .timeMachineBackup:    return "Time Machine backup"
        case .busProtocol:          return "Bus/protocol"
        case .isSSD:                return "SSD"
        }
    }

    var category: String {
        switch self {
        case .smartStatus, .healthScore, .temperature, .powerOnHours, .powerCycles,
             .startStops, .loadCycles, .udmaCRCErrors, .reallocatedSectors,
             .pendingSectors, .offlineUncorrectable, .gSenseErrors,
             .multiZoneErrors, .wearLevel, .percentageUsed:
            return "SMART / Drive"
        case .freeSpace, .filesystemVerify, .fileVault,
             .encryption, .timeMachineBackup:
            return "Volume / System"
        case .busProtocol, .isSSD:
            return "Identity"
        }
    }

    var isVisibleByDefault: Bool {
        switch self {
        case .smartStatus, .healthScore, .freeSpace, .temperature, .powerOnHours,
             .reallocatedSectors, .pendingSectors, .wearLevel, .percentageUsed,
             .fileVault, .encryption, .timeMachineBackup:
            return true
        default:
            return false
        }
    }
}

// MARK: - Persistent selection store

/// Persists which health metrics the user wants to see.
/// The selection is saved to UserDefaults automatically on every change.
@Observable
@MainActor
final class DiskHealthMetricsStore {
    static let shared = DiskHealthMetricsStore()

    private let defaultsKey = "apex.diskHealthMetrics.selection"

    private(set) var selected: Set<DiskHealthMetric> = []

    private init() {
        selected = loadSelection()
    }

    func isSelected(_ metric: DiskHealthMetric) -> Bool {
        selected.contains(metric)
    }

    func toggle(_ metric: DiskHealthMetric) {
        if selected.contains(metric) {
            selected.remove(metric)
        } else {
            selected.insert(metric)
        }
        saveSelection(selected)
    }

    func resetToDefaults() {
        selected = Set(DiskHealthMetric.allCases.filter(\.isVisibleByDefault))
        saveSelection(selected)
    }

    // MARK: - Persistence

    private func loadSelection() -> Set<DiskHealthMetric> {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(Set<DiskHealthMetric>.self, from: data)
        else {
            return Set(DiskHealthMetric.allCases.filter(\.isVisibleByDefault))
        }
        return decoded
    }

    private func saveSelection(_ selection: Set<DiskHealthMetric>) {
        if let data = try? JSONEncoder().encode(selection) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
