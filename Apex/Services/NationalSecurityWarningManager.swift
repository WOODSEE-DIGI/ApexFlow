import SwiftUI
import AppKit
import Darwin

// MARK: - National Security Warning Manager
/// Presents an over-the-top, full-screen warning on the display that currently
/// contains the ApexFlow window. Used for system-wide resource threats (memory
/// hogs, CPU hogs, system memory pressure).
@MainActor
final class NationalSecurityWarningManager {
    static let shared = NationalSecurityWarningManager()

    private var window: NSWindow?
    private var onDismiss: (() -> Void)?

    private init() {}

    /// Present a full-screen warning on the display where ApexFlow lives.
    /// - Parameters:
    ///   - threats: One or more resource threats to display.
    ///   - networkLeakData: Optional WAN leak data store for investigation and
    ///     user actions when a threat is a WAN leak.
    ///   - onDismiss: Called when the user dismisses the warning.
    func present(
        threats: [ThreatAssessment],
        networkLeakData: NetworkLeakData? = nil,
        onDismiss: @escaping () -> Void
    ) {
        guard window == nil, !threats.isEmpty else { return }

        self.onDismiss = onDismiss

        let content = NationalSecurityWarningView(
            threats: threats,
            networkLeakData: networkLeakData,
            onDismiss: { [weak self] in
                self?.dismiss()
            },
            onKill: { [weak self] pid in
                self?.killProcess(pid: pid)
            }
        )

        let hosting = NSHostingController(rootView: content)

        // Target the screen that contains an ApexFlow window. mainWindow can be
        // nil for menu-bar-only apps, so also check keyWindow and any visible
        // window owned by this app before falling back to the main display.
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
        // Make the hosting view fill the window exactly.
        hosting.view.frame = NSRect(origin: .zero, size: frame.size)
        hosting.view.autoresizingMask = [.width, .height]
        win.contentViewController = hosting

        // modalPanel keeps us on top while still allowing clicks/keyboard.
        win.level = .modalPanel
        win.collectionBehavior = [.fullScreenAuxiliary]
        win.backgroundColor = .black
        win.isOpaque = true
        win.hasShadow = false
        win.isReleasedWhenClosed = false
        win.acceptsMouseMovedEvents = true
        win.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        win.makeFirstResponder(hosting.view)

        self.window = win
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
        onDismiss?()
        onDismiss = nil
    }

    private func killProcess(pid: Int32) {
        if pid == getpid() {
            NSApp.terminate(nil)
        } else if pid > 0 {
            kill(pid, SIGTERM)
        }
    }
}
