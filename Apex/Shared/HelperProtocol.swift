import Foundation

/// XPC protocol shared between the main Apex Flow app and the ApexFlowHelper daemon.
/// Compiled into both targets — keep this file free of any AppKit/SwiftUI imports.
@objc(ApexHelperProtocol)
protocol ApexHelperProtocol {
    /// Send a signal to a process. Returns (true, "") on success or (false, errno string) on failure.
    func killProcess(pid: Int32, signal: Int32,
                     withReply reply: @escaping (Bool, String) -> Void)

    /// Returns the helper's version string.
    func getVersion(withReply reply: @escaping (String) -> Void)
}
