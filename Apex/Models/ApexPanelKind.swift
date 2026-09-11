import SwiftUI

// MARK: - Apex Panel Kind
/// Identifies one of the dynamic, movable monitor panels in Apex Flow.
/// This is intentionally scoped to the existing dashboard panels — no
/// third-party apps or open-ended panel kinds.
enum ApexPanelKind: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case cpu
    case memory
    case network
    case connectivity
    case aiModel
    case processes
    case diskHealth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory & Disks"
        case .network: return "Network"
        case .connectivity: return "Connectivity"
        case .aiModel: return "AI Model"
        case .processes: return "Processes"
        case .diskHealth: return "Storage Health"
        }
    }

    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .network: return "network"
        case .connectivity: return "bolt.horizontal"
        case .aiModel: return "sparkles"
        case .processes: return "list.bullet.rectangle"
        case .diskHealth: return "externaldrive.badge.checkmark"
        }
    }

    /// Minimum comfortable width in pixels. Used to compute the grid span.
    var minWidth: CGFloat {
        switch self {
        case .cpu, .processes: return 360
        case .connectivity, .aiModel: return 420
        case .diskHealth: return 400
        default: return 320
        }
    }

    /// Preferred initial grid span (colSpan, rowSpan) for the 12×12 canvas.
    var preferredSpan: (col: Int, row: Int) {
        switch self {
        case .cpu: return (12, 2)
        case .memory: return (6, 2)
        case .network: return (6, 2)
        case .connectivity: return (6, 2)
        case .aiModel: return (6, 2)
        case .processes: return (12, 2)
        case .diskHealth: return (12, 2)
        }
    }
}
