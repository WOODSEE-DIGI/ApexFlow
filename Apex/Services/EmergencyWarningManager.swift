import SwiftUI
import AppKit
import Darwin

// MARK: - Emergency Warning Manager
/// Presents a full-screen, always-on-top warning window that the user can use
/// to terminate ApexFlow (or another target process) when the app enters a
/// runaway state or when a manual panic button is pressed.
@MainActor
final class EmergencyWarningManager {
    static let shared = EmergencyWarningManager()

    private var window: NSWindow?

    private init() {}

    /// Present a full-screen emergency warning.
    /// - Parameters:
    ///   - reason: Short headline for why the warning appeared.
    ///   - detail: Human-readable explanation.
    ///   - targetPID: Process to kill when the user presses the kill button.
    ///                Defaults to ApexFlow's own PID.
    func present(
        reason: EmergencyReason,
        detail: String,
        targetPID: Int32 = getpid()
    ) {
        guard window == nil else { return }

        let content = EmergencyWarningView(
            reason: reason,
            detail: detail,
            targetPID: targetPID,
            onDismiss: { [weak self] in
                self?.dismiss()
            },
            onKill: { [weak self] in
                self?.sendKillSignal(pid: targetPID)
            }
        )

        let hosting = NSHostingController(rootView: content)
        // Target the screen that contains an ApexFlow window.
        let screen: NSScreen? = {
            if let main = NSApp.mainWindow?.screen { return main }
            if let key = NSApp.keyWindow?.screen { return key }
            if let visible = NSApp.windows.first(where: { $0.isVisible && $0.screen != nil })?.screen {
                return visible
            }
            return NSScreen.main ?? NSScreen.screens.first
        }()
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)

        let win = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // Force the SwiftUI content to fill the entire screen.
        hosting.view.frame = NSRect(origin: .zero, size: frame.size)
        hosting.view.autoresizingMask = [.width, .height]
        win.contentViewController = hosting
        win.level = .modalPanel
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.backgroundColor = .black
        win.isOpaque = false
        win.hasShadow = false
        win.isReleasedWhenClosed = false
        win.acceptsMouseMovedEvents = true
        win.makeKeyAndOrderFront(nil)

        // Keep it on top and capture attention.
        NSApp.activate(ignoringOtherApps: true)
        win.makeFirstResponder(hosting.view)

        self.window = win
    }

    /// Dismiss the warning without killing anything.
    func dismiss() {
        window?.orderOut(nil)
        window = nil
    }

    private func sendKillSignal(pid: Int32) {
        // If targeting ourselves, use AppKit's terminate path so the app gets
        // a chance to clean up. For other processes, send SIGTERM directly.
        if pid == getpid() {
            NSApp.terminate(nil)
        } else {
            kill(pid, SIGTERM)
            dismiss()
        }
    }
}
