import Foundation
import Observation

// MARK: - Warning Display Mode
/// How the user wants to be notified about system threats and WAN leaks.
enum WarningDisplayMode: String, Codable, CaseIterable, Identifiable {
    case fullScreen = "Full Screen"
    case cornerNotification = "Corner Notification"
    case mainWindowOnly = "Main Window Only"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .fullScreen:
            return "Dramatic full-screen alert with actions."
        case .cornerNotification:
            return "Small notification in the top-right corner."
        case .mainWindowOnly:
            return "No popup; flash the relevant panel in the main window."
        }
    }
}

// MARK: - Warning Settings
/// User-facing configuration for threat / WAN leak notifications.
@Observable
@MainActor
final class WarningSettings {
    static let shared = WarningSettings()

    private let defaultsKey = "apex.warning.settings.v2"

    /// How system-wide threat warnings should be presented.
    var displayMode: WarningDisplayMode = .fullScreen

    private init() {
        load()
    }

    func setDisplayMode(_ mode: WarningDisplayMode) {
        displayMode = mode
        save()
    }

    // MARK: - Persistence

    private func save() {
        let payload: [String: String] = [
            "displayMode": displayMode.rawValue
        ]
        UserDefaults.standard.set(payload, forKey: defaultsKey)
    }

    private func load() {
        guard let payload = UserDefaults.standard.object(forKey: defaultsKey) as? [String: String],
              let raw = payload["displayMode"],
              let mode = WarningDisplayMode(rawValue: raw)
        else { return }
        displayMode = mode
    }
}
