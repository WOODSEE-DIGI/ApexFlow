import SwiftUI

struct ContentView: View {
    let monitor: SystemMonitor

    @State private var layout = ApexWorkspaceLayoutState.shared
    @State private var showingThemeSettings = false
    @State private var showingSaveLayout = false
    @State private var newLayoutName = ""
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

                    layoutMenu

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
        .sheet(isPresented: $showingSaveLayout) {
            SaveLayoutSheet(name: $newLayoutName) { name in
                layout.saveCurrentLayout(as: name)
                showingSaveLayout = false
            }
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

    private var layoutMenu: some View {
        Menu {
            Button {
                layout.resetDefaultLayout()
            } label: {
                Label("Reset to Default", systemImage: "arrow.counterclockwise")
            }

            if !layout.savedLayoutNames.isEmpty {
                Divider()
                ForEach(layout.savedLayoutNames, id: \.self) { name in
                    Button {
                        layout.loadLayout(named: name)
                    } label: {
                        Text(name)
                        if layout.currentLayoutName == name {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()
            Button {
                newLayoutName = ""
                showingSaveLayout = true
            } label: {
                Label("Save Current Layout...", systemImage: "square.and.arrow.down")
            }
        } label: {
            Image(systemName: "square.grid.2x2")
                .foregroundStyle(theme.subtext1)
        }
        .menuStyle(.borderlessButton)
        .help("Layouts")
    }
}

// MARK: - Save Layout Sheet

private struct SaveLayoutSheet: View {
    @Binding var name: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save layout")
                .font(.system(size: 14, weight: .bold))

            TextField("Layout name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.borderless)
                Button("Save") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 300)
        .background(theme.base)
    }
}
