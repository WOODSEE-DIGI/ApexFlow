import Foundation

/// A central registry to bridge the gap between active AI sessions (which have token telemetry)
/// and the system-level AIModelCollector (which monitors processes).
/// All state is MainActor-isolated because `AIModelData` is MainActor-isolated.
@MainActor
final class AIModelRegistry {
    static let shared = AIModelRegistry()

    private init() {}

    /// Stores active AI model data instances, keyed by their process name or PID.
    private var activeModels: [String: AIModelData] = [:]

    /// Registers an active AI model session.
    /// - Parameters:
    ///   - processName: The name of the process (e.g., "SwiftMaestro")
    ///   - modelData: The AIModelData instance tracking the session.
    func register(_ modelData: AIModelData, for processName: String) {
        activeModels[processName.lowercased()] = modelData
    }

    /// Unregisters an AI model session.
    func unregister(for processName: String) {
        activeModels.removeValue(forKey: processName.lowercased())
    }

    /// Retrieves telemetry data for a specific process name.
    func getTelemetry(for processName: String) -> (tokensPerSecond: Double, totalTokens: Int)? {
        guard let model = activeModels[processName.lowercased()] else { return nil }

        // We return a snapshot of the current telemetry
        return (
            tokensPerSecond: model.tokenActivity.tokensPerSecond,
            totalTokens: model.tokenActivity.totalTokens
        )
    }

    /// Returns all currently registered telemetry data.
    func getAllTelemetry() -> [String: (tokensPerSecond: Double, totalTokens: Int)] {
        return activeModels.mapValues { model in
            (tokensPerSecond: model.tokenActivity.tokensPerSecond, totalTokens: model.tokenActivity.totalTokens)
        }
    }
}