import SwiftUI

struct ContentView: View {
    let monitor: SystemMonitor

    @State private var layout = ApexWorkspaceLayoutState.shared
    @State private var showingThemeSettings = false
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        ZStack {
            ApexCanvasWorkspaceView(monitor: monitor)

            VStack {
                HStack {
                    Text("Apex Flow")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.text)
                        .padding(.leading, 12)

                    Spacer()

                    panelToggleMenu

                    Button {
                        layout.isLocked.toggle()
                    } label: {
                        Image(systemName: layout.isLocked ? "lock" : "lock.open")
                            .foregroundStyle(theme.subtext1)
                    }
                    .buttonStyle(.plain)
                    .help(layout.isLocked ? "Unlock layout" : "Lock layout")

                    Button {
                        showingThemeSettings = true
                    } label: {
                        Image(systemName: "paintbrush")
                            .foregroundStyle(theme.subtext1)
                    }
                    .buttonStyle(.plain)
                    .help("Customize theme")

                    Button {
                        layout.resetDefaultLayout()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(theme.subtext1)
                    }
                    .buttonStyle(.plain)
                    .help("Reset default layout")
                    .padding(.trailing, 12)
                }
                .padding(.vertical, 8)
                .background(theme.base.opacity(0.85))

                Spacer()
            }
        }
        .background(theme.base)
        .frame(minWidth: 1050, minHeight: 750)
        .sheet(isPresented: $showingThemeSettings) {
            ThemeSettingsView()
                .environment(theme)
        }
    }

    private var panelToggleMenu: some View {
        Menu {
            ForEach(ApexPanelKind.allCases) { kind in
                Button {
                    layout.toggle(kind)
                } label: {
                    Label(kind.title, systemImage: kind.icon)
                    if layout.isOpen(kind) {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Image(systemName: "rectangle.split.2x2")
                .foregroundStyle(theme.subtext1)
        }
        .menuStyle(.borderlessButton)
        .help("Toggle panels")
    }
}
