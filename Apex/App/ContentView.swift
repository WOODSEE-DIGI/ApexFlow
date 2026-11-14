import SwiftUI

struct ContentView: View {
    let monitor: SystemMonitor

    let layout = ApexWorkspaceLayoutState.shared
    @State private var showingThemeSettings = false
    @State private var showingSaveLayout = false
    @State private var showingDeleteLayout = false
    @State private var newLayoutName = ""
    @Environment(ThemeStore.self) private var theme

    var body: some View {
        VStack(spacing: 0) {
            ApexCanvasWorkspaceView(monitor: monitor)
        }
        .background(theme.base)
        .frame(minWidth: 1050, minHeight: 750)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                workspaceMenu

                Button {
                    showingThemeSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(theme.subtext1)
                }
                .help("Settings")

                Button {
                    layout.resetDefaultLayout()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(theme.subtext1)
                }
                .help("Reset default layout")
            }
        }
        .sheet(isPresented: $showingThemeSettings) {
            SettingsView()
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

    private var workspaceMenu: some View {
        Menu {
            Section("Panels") {
                ForEach(ApexPanelKind.allCases) { kind in
                    Button {
                        layout.toggle(kind)
                    } label: {
                        Label(kind.title, systemImage: kind.icon)
                        if layout.isOpen(kind) {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Section("Layouts") {
                if !layout.savedLayoutNames.isEmpty {
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

                    Divider()
                }

                Button {
                    newLayoutName = ""
                    showingSaveLayout = true
                } label: {
                    Label("Save Current Layout...", systemImage: "square.and.arrow.down")
                }

                Button {
                    showingDeleteLayout = true
                } label: {
                    Label("Delete Layout...", systemImage: "trash")
                }
                .disabled(layout.savedLayoutNames.isEmpty)
            }

            Section("Workspace") {
                Button {
                    layout.isLocked.toggle()
                } label: {
                    Label(layout.isLocked ? "Unlock Workspace" : "Lock Workspace", systemImage: layout.isLocked ? "lock" : "lock.open")
                }
            }
        } label: {
            Image(systemName: "square.grid.2x2")
                .foregroundStyle(theme.subtext1)
        }
        .help("Workspace")
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
