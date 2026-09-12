import Foundation
import Observation

// MARK: - Risk Level

enum WANAlertRisk: String, Codable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var colorName: String {
        switch self {
        case .low:    return "green"
        case .medium: return "yellow"
        case .high:   return "red"
        }
    }
}

// MARK: - WAN Connection Alert

struct WANConnectionAlert: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let pid: Int32
    let processName: String
    let bundleID: String?
    let remoteAddress: String
    let remotePort: Int
    let localAddress: String
    let localPort: Int
    let protocolName: String
    let timestamp: Date
    let risk: WANAlertRisk
    let advice: String
    let reason: String
    var resolvedHostname: String?

    var displayName: String {
        bundleID?.components(separatedBy: ".").last?.localizedCapitalized
            ?? processName
    }

    var remoteEndpoint: String { "\(remoteAddress):\(remotePort)" }

    var displayEndpoint: String {
        if let host = resolvedHostname, !host.isEmpty {
            return "\(host):\(remotePort)"
        }
        return remoteEndpoint
    }
}

// MARK: - Leak Monitor Settings

struct NetworkLeakSettings: Codable {
    var isEnabled: Bool = true
    var ignorePrivateTraffic: Bool = true
    var approvedBundles: Set<String> = []
    var approvedProcesses: Set<String> = []
    var silencedEndpoints: Set<String> = []
}

// MARK: - Observable State

@Observable
@MainActor
final class NetworkLeakData {
    var alerts: [WANConnectionAlert] = []
    var isEnabled = true
    var ignoredPrivate = true
    var unreadCount = 0

    private let settingsKey = "apex.networkLeak.settings"
    private(set) var settings: NetworkLeakSettings {
        didSet { saveSettings() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(NetworkLeakSettings.self, from: data) {
            settings = decoded
        } else {
            settings = NetworkLeakSettings()
        }
        isEnabled = settings.isEnabled
        ignoredPrivate = settings.ignorePrivateTraffic
    }

    func add(_ alert: WANConnectionAlert) {
        guard isEnabled else { return }
        // Deduplicate exact endpoint within the last 60s.
        let recent = Date().addingTimeInterval(-60)
        if alerts.contains(where: {
            $0.pid == alert.pid &&
            $0.remoteAddress == alert.remoteAddress &&
            $0.remotePort == alert.remotePort &&
            $0.timestamp > recent
        }) { return }

        alerts.insert(alert, at: 0)
        if alerts.count > 200 { alerts.removeLast() }
        unreadCount += 1
    }

    func markRead() {
        unreadCount = 0
    }

    func dismiss(_ alert: WANConnectionAlert) {
        alerts.removeAll { $0.id == alert.id }
    }

    func setResolvedHostname(id: String, hostname: String?) {
        guard let idx = alerts.firstIndex(where: { $0.id == id }) else { return }
        alerts[idx].resolvedHostname = hostname
    }

    func approve(_ alert: WANConnectionAlert) {
        if let bundle = alert.bundleID, !bundle.isEmpty {
            settings.approvedBundles.insert(bundle)
        } else {
            settings.approvedProcesses.insert(alert.processName)
        }
        dismiss(alert)
    }

    func silenceEndpoint(_ alert: WANConnectionAlert) {
        settings.silencedEndpoints.insert(alert.remoteEndpoint)
        dismiss(alert)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        settings.isEnabled = enabled
    }

    func setIgnorePrivate(_ ignore: Bool) {
        ignoredPrivate = ignore
        settings.ignorePrivateTraffic = ignore
    }

    func isApproved(_ alert: WANConnectionAlert) -> Bool {
        if let bundle = alert.bundleID, settings.approvedBundles.contains(bundle) { return true }
        if settings.approvedProcesses.contains(alert.processName) { return true }
        if settings.silencedEndpoints.contains(alert.remoteEndpoint) { return true }
        return false
    }

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }
}
