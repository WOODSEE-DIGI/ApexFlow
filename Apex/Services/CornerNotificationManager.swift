import SwiftUI
import AppKit

// MARK: - Corner Notification Manager
/// Presents a small, non-intrusive notification window in the top-right corner
/// of the screen that contains the ApexFlow window. Used when the user chooses
/// "Corner Notification" for threat / WAN leak alerts.
@MainActor
final class CornerNotificationManager {
    static let shared = CornerNotificationManager()

    private var window: NSWindow?
    private var dismissTimer: Timer?

    private init() {}

    /// Show a corner notification for a threat.
    /// - Parameters:
    ///   - title: Short headline, e.g. "WAN LEAK DETECTED".
    ///   - body: One or two lines describing the threat.
    ///   - themeColor: Accent color matching the threat type.
    ///   - autoDismiss: Seconds before the notification fades. Default 8.
    func present(
        title: String,
        body: String,
        themeColor: Color,
        autoDismiss: TimeInterval = 8.0
    ) {
        dismiss()

        let content = CornerNotificationView(
            title: title,
            message: body,
            themeColor: themeColor,
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let hosting = NSHostingController(rootView: content)
        let size = NSSize(width: 320, height: 110)

        // Target the screen that contains an ApexFlow window.
        let screen: NSScreen? = {
            if let main = NSApp.mainWindow?.screen { return main }
            if let key = NSApp.keyWindow?.screen { return key }
            if let visible = NSApp.windows.first(where: { $0.isVisible && $0.screen != nil })?.screen {
                return visible
            }
            return NSScreen.main ?? NSScreen.screens.first
        }()
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let origin = NSPoint(
            x: screenFrame.maxX - size.width - 16,
            y: screenFrame.maxY - size.height - 16
        )

        let win = NSWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        hosting.view.frame = NSRect(origin: .zero, size: size)
        hosting.view.autoresizingMask = [.width, .height]
        win.contentViewController = hosting

        win.level = .modalPanel
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = true
        win.isReleasedWhenClosed = false
        win.acceptsMouseMovedEvents = true
        win.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.window = win

        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismiss, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismiss()
            }
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        window?.orderOut(nil)
        window = nil
    }
}

// MARK: - Corner Notification View

private struct CornerNotificationView: View {
    let title: String
    let message: String
    let themeColor: Color
    let onDismiss: () -> Void

    @State private var opacity = 0.0
    @State private var offset: CGFloat = -20

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(themeColor)
                Text(title)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            Text(message)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Text("Click to open Apex Flow")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(12)
        .background(.black.opacity(0.85))
        .overlay(
            Rectangle()
                .stroke(themeColor, lineWidth: 2)
        )
        .cornerRadius(8)
        .shadow(color: themeColor.opacity(0.4), radius: 12)
        .opacity(opacity)
        .offset(y: offset)
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                opacity = 1.0
                offset = 0
            }
        }
        .onTapGesture {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.mainWindow?.makeKeyAndOrderFront(nil)
            onDismiss()
        }
    }
}
