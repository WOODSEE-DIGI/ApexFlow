import Foundation
import Observation
import ServiceManagement

/// Manages the lifecycle of the ApexFlowHelper privileged daemon and its XPC connection.
///
/// Usage:
///   - Call `registerIfNeeded()` on app startup to install the daemon via SMAppService.
///   - Call `kill(pid:signal:)` to send a signal to any process (including root-owned ones).
@Observable
@MainActor
final class HelperManager {

    static let shared = HelperManager()

    // MARK: - State
    enum HelperStatus: CustomStringConvertible {
        case unknown
        case notInstalled
        case requiresApproval   // User must approve in System Settings
        case installed
        case error(String)

        var description: String {
            switch self {
            case .unknown:          return "Checking…"
            case .notInstalled:     return "Not installed"
            case .requiresApproval: return "Approval required"
            case .installed:        return "Running"
            case .error(let msg):   return "Error: \(msg)"
            }
        }

        var isReady: Bool {
            if case .installed = self { return true }
            return false
        }
    }

    var status: HelperStatus = .unknown
    var lastError: String?

    // MARK: - SMAppService
    private static let daemonPlistName = "com.woodsee-digi.ApexFlowHelper.plist"
    private var service: SMAppService { SMAppService.daemon(plistName: Self.daemonPlistName) }

    /// Register (install) the helper daemon via SMAppService.
    /// On first call, macOS shows an authorization prompt. Subsequent calls are instant.
    func registerIfNeeded() {
        let currentStatus = service.status
        switch currentStatus {
        case .enabled:
            status = .installed
        case .notRegistered, .notFound:
            do {
                try service.register()
                status = .installed
            } catch {
                let msg = error.localizedDescription
                status = .error(msg)
                lastError = msg
            }
        case .requiresApproval:
            status = .requiresApproval
        @unknown default:
            status = .unknown
        }
    }

    /// Open System Settings so the user can approve the helper.
    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: - XPC connection
    private var _connection: NSXPCConnection?

    private func connection() -> NSXPCConnection {
        if let c = _connection { return c }
        let c = NSXPCConnection(machServiceName: "com.woodsee-digi.ApexFlowHelper",
                                options: .privileged)
        c.remoteObjectInterface = NSXPCInterface(with: ApexHelperProtocol.self)
        c.invalidationHandler = { [weak self] in
            Task { @MainActor in self?._connection = nil }
        }
        c.interruptionHandler = { [weak self] in
            Task { @MainActor in self?._connection = nil }
        }
        c.resume()
        _connection = c
        return c
    }

    private func proxy() -> ApexHelperProtocol? {
        connection().remoteObjectProxy as? ApexHelperProtocol
    }

    // MARK: - Kill API
    enum KillError: LocalizedError {
        case helperNotAvailable
        case permissionDenied(String)
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case .helperNotAvailable: return "ApexFlowHelper is not running. Enable it in System Settings → General → Login Items."
            case .permissionDenied(let msg): return "Permission denied: \(msg)"
            case .unknown(let msg):   return msg
            }
        }
    }

    /// Send a signal to a process via the privileged helper.
    /// Falls back to a direct `Darwin.kill()` call if the helper is not available
    /// (i.e. in development builds without the daemon installed).
    @discardableResult
    func kill(pid: Int32, signal: Int32) async -> Result<Void, KillError> {
        // Fast path: try direct kill first (works for user-owned processes without helper)
        if Darwin.kill(pid, signal) == 0 { return .success(()) }
        let directErrno = errno

        // If EPERM, delegate to privileged helper
        guard directErrno == EPERM else {
            let msg = String(cString: strerror(directErrno))
            return .failure(.unknown(msg))
        }

        guard let p = proxy() else {
            return .failure(.helperNotAvailable)
        }

        return await withCheckedContinuation { continuation in
            p.killProcess(pid: pid, signal: signal) { success, errorMsg in
                if success {
                    continuation.resume(returning: .success(()))
                } else if errorMsg.contains("denied") || errorMsg.contains("Operation not permitted") {
                    continuation.resume(returning: .failure(.permissionDenied(errorMsg)))
                } else {
                    continuation.resume(returning: .failure(.unknown(errorMsg)))
                }
            }
        }
    }
}
