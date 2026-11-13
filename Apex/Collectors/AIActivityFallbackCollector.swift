import Foundation

// MARK: - AI Activity Fallback Collector

/// Fallback activity detector for when SwiftMaestro's distributed token-rate
/// notifications are not reaching ApexFlow. It samples AI-related process CPU
/// usage and, if a model request is in flight while a model engine or active
/// client is consuming CPU, returns an estimated rate so the panel does not sit
/// at 0 tks/s during live inference.
///
/// This is an `actor` rather than a `@MainActor` class so the work can run off
/// the main thread and so it never has to hold a reference to the
/// `@MainActor`-isolated `AIModelData`. The caller passes in a simple boolean
/// indicating whether a request is active and applies any returned token rate
/// on the main actor itself.
actor AIActivityFallbackCollector {

    /// Minimum CPU% that suggests a model engine is actually working.
    /// Kept low because MLX inference on Apple Silicon may not show high host CPU.
    private static let modelEngineCPUThreshold: Double = 1.0

    /// Minimum CPU% for a client app (SwiftMaestro / OpenCode) that is
    /// actively receiving/rendering a streaming response.
    private static let clientCPUThreshold: Double = 1.0

    /// Seconds of sustained activity before we start emitting tokens.
    private static let sustainedActivitySeconds: TimeInterval = 2.0

    /// Rough tokens-per-second estimate derived from CPU load. This is
    /// intentionally conservative; without the real token stream it is only
    /// an indicator that inference is happening.
    private static func estimatedTPS(cpuPercent: Double, isModelEngine: Bool) -> Double {
        // Model engines on Apple Silicon/MLX may offload to GPU/ANE, so their
        // host CPU is not linearly related to throughput. Clients spend CPU
        // parsing/rendering tokens, which is a slightly better signal.
        let factor = isModelEngine ? 0.25 : 0.5
        return max(0.5, cpuPercent * factor)
    }

    // MARK: - State

    private struct Sample: Sendable {
        let timestamp: Date
        let cpuPercent: Double
        let isModelEngine: Bool
        let name: String
    }

    private struct State {
        var history: [Int32: [Sample]] = [:]
        var lastEmittedTokenTime: Date = .distantPast
    }

    private var state = State()

    // MARK: - Public

    /// A small value-type result so callers on the main actor can apply the
    /// fallback token without sharing `AIModelData` across isolation boundaries.
    struct Result: Sendable {
        let name: String
        let cpuPercent: Double
        let tokensPerSecond: Double
    }

    /// Call on every AI process refresh (currently every 2s from AIModelCollector).
    /// We keep a short rolling history and emit fallback tokens when we see
    /// sustained CPU load during an active request.
    func update(with processes: [AIModelSnapshot], requestActive: Bool) -> Result? {
        let now = Date()

        // Only fallback while a request lifecycle has been started. If the
        // broadcaster sent generationStarted but no token updates, we fill the gap.
        guard requestActive else {
            state.history.removeAll()
            return nil
        }

        // Record samples for every process we care about.
        for proc in processes {
            let isEngine = proc.kind == .modelEngine || (proc.kind == .mcpServer && proc.isActiveServer)
            let threshold = isEngine ? Self.modelEngineCPUThreshold : Self.clientCPUThreshold
            guard proc.cpuPercent >= threshold else { continue }

            let sample = Sample(
                timestamp: now,
                cpuPercent: proc.cpuPercent,
                isModelEngine: isEngine,
                name: proc.name
            )
            state.history[proc.id, default: []].append(sample)
        }

        // Prune stale samples older than 5 seconds.
        for pid in state.history.keys {
            state.history[pid]?.removeAll { now.timeIntervalSince($0.timestamp) > 5.0 }
            if state.history[pid]?.isEmpty == true {
                state.history.removeValue(forKey: pid)
            }
        }

        // Find any PID with sustained activity across at least two samples.
        var bestPID: Int32?
        var bestAvgCPU: Double = 0
        var bestIsEngine = false
        var bestName = ""

        for (pid, samples) in state.history {
            guard samples.count >= 2 else { continue }
            let duration = samples.last!.timestamp.timeIntervalSince(samples.first!.timestamp)
            let avgCPU = samples.map(\.cpuPercent).reduce(0, +) / Double(samples.count)
            let threshold = samples.first!.isModelEngine ? Self.modelEngineCPUThreshold : Self.clientCPUThreshold
            guard duration >= Self.sustainedActivitySeconds, avgCPU >= threshold else { continue }

            // Prefer model engines, then highest average CPU.
            if bestPID == nil
                || (samples.first!.isModelEngine && !bestIsEngine)
                || avgCPU > bestAvgCPU {
                bestPID = pid
                bestAvgCPU = avgCPU
                bestIsEngine = samples.first!.isModelEngine
                bestName = samples.first!.name
            }
        }

        guard bestPID != nil else { return nil }

        // Throttle fallback tokens to ~1/sec to match the broadcaster's own rate.
        guard now.timeIntervalSince(state.lastEmittedTokenTime) >= 1.0 else { return nil }
        state.lastEmittedTokenTime = now

        let tps = Self.estimatedTPS(cpuPercent: bestAvgCPU, isModelEngine: bestIsEngine)

        return Result(name: bestName, cpuPercent: bestAvgCPU, tokensPerSecond: tps)
    }
}
