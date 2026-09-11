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
                    // Register the privileged helper daemon via SMAppService.
                    // No-op in development builds where the daemon isn't installed.
                    HelperManager.shared.registerIfNeeded()
                }
                .onDisappear { monitor.stop() }
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
        }
    }
}
