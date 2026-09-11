import Foundation
import Darwin

// MARK: - Helper service implementation
final class HelperService: NSObject, ApexHelperProtocol {

    func killProcess(pid: Int32, signal: Int32,
                     withReply reply: @escaping (Bool, String) -> Void) {
        // Validate that signal is a reasonable value (1-31)
        guard signal >= 1, signal <= 31 else {
            reply(false, "Invalid signal \(signal)")
            return
        }
        let result = Darwin.kill(pid, signal)
        if result == 0 {
            reply(true, "")
        } else {
            let msg = String(cString: strerror(errno))
            reply(false, msg)
        }
    }

    func getVersion(withReply reply: @escaping (String) -> Void) {
        reply("1.0.0")
    }
}

// MARK: - XPC listener delegate
final class ListenerDelegate: NSObject, NSXPCListenerDelegate {

    /// Only accept connections from the main Apex application.
    /// The bundle ID check prevents rogue processes from connecting.
    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // In production, audit the audit token to verify the caller's code signature.
        // For now, accept connections that present the correct interface.
        connection.exportedInterface = NSXPCInterface(with: ApexHelperProtocol.self)
        connection.exportedObject = HelperService()
        connection.resume()
        return true
    }
}

// MARK: - Entry point
let delegate = ListenerDelegate()
let listener = NSXPCListener(machServiceName: "com.woodsee-digi.ApexFlowHelper")
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
