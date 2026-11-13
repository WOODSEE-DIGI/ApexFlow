import SwiftUI

struct ContentView: View {
    let monitor: SystemMonitor

    @State private var layout = ApexWorkspaceLayoutState.shared
    @State private var showingThemeSettings = false
    @State private var showingSaveLayout = false
    @State private var showingDeleteLayout = false
    @State private var newLayoutName = ""
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Apex Flow")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .padding(.leading, 12)

                Spacer()

                panelToggleMenu

                layoutMenu

                Button {
                    newLayoutName = ""
                    showingSaveLayout = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(theme.subtext1)
                }
                .buttonStyle(.plain)
                .help("Save current layout")

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
            .background(theme.base)

            ApexCanvasWorkspaceView(monitor: monitor)
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
        .sheet(isPresented: $showingDeleteLayout) {
            DeleteLayoutSheet(layoutNames: layout.savedLayoutNames) { name in
                layout.deleteLayout(named: name)
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
                // Present the sheet after the menu closes to avoid SwiftUI
                // menu hit-testing issues on macOS.
                DispatchQueue.main.async {
                    newLayoutName = ""
                    showingSaveLayout = true
                }
            } label: {
                Label("Save Current Layout...", systemImage: "square.and.arrow.down")
            }

            Button {
                DispatchQueue.main.async {
                    showingDeleteLayout = true
                }
            } label: {
                Label("Delete Layout...", systemImage: "trash")
            }
            .disabled(layout.savedLayoutNames.isEmpty)
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

// MARK: - Delete Layout Sheet

private struct DeleteLayoutSheet: View {
    let layoutNames: [String]
    let onDelete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delete layout")
                .font(.system(size: 14, weight: .bold))

            if layoutNames.isEmpty {
                Text("No saved layouts to delete.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.subtext1)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(layoutNames, id: \.self) { name in
                            HStack {
                                Text(name)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(theme.text)

                                Spacer()

                                Button {
                                    onDelete(name)
                                    if layoutNames.count == 1 {
                                        dismiss()
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                                .help("Delete '\(name)'")
                            }
                            .padding(8)
                            .background(theme.surface0)
                            .cornerRadius(6)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 320)
        .background(theme.base)
    }
}
