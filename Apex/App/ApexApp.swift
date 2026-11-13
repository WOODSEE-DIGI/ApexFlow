import SwiftUI

@main
struct ApexApp: App {
    @State private var monitor = SystemMonitor()
    @State private var theme = ThemeStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView(monitor: monitor)
                .environment(theme)
                .preferredColorScheme(theme.appearance.colorScheme)
                .task {
                    theme.applyInitialAppearance()
                    monitor.start()
                    AppHealthWatchdog.shared.start()
                    SystemThreatMonitor.shared.start()
                    // Register the privileged helper daemon via SMAppService.
                    // No-op in development builds where the daemon isn't installed.
                    HelperManager.shared.registerIfNeeded()
                }
                .onDisappear {
                    monitor.stop()
                    AppHealthWatchdog.shared.stop()
                    SystemThreatMonitor.shared.stop()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 820)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Apex") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            CommandGroup(after: .appInfo) {
                Button("Emergency Kill Switch…") {
                    EmergencyWarningManager.shared.present(
                        reason: .manualTrigger,
                        detail: "Manual panic button pressed. Terminate ApexFlow if it is unresponsive or consuming excessive resources.",
                        targetPID: getpid()
                    )
                }
                .keyboardShortcut("K", modifiers: [.command, .shift, .option])
            }
        }
    }
}
