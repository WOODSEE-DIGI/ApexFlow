import SwiftUI

// MARK: - Settings View
/// A proper macOS-style settings window for Apex Flow.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var theme
    @Bindable var warningSettings = WarningSettings.shared
    @Bindable var leakData = NetworkLeakData.shared

    @State private var selectedSection: SettingsSection = .alerts

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 160)
        } detail: {
            Form {
                switch selectedSection {
                case .alerts:
                    AlertsSettingsSection()
                case .appearance:
                    AppearanceSettingsSection()
                case .network:
                    NetworkSettingsSection()
                }
            }
            .formStyle(.grouped)
            .navigationTitle(selectedSection.title)
        }
        .frame(minWidth: 640, minHeight: 520)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

// MARK: - Settings Sections

private enum SettingsSection: String, CaseIterable, Identifiable {
    case alerts
    case appearance
    case network

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alerts:     return "Alerts"
        case .appearance: return "Appearance"
        case .network:    return "Network"
        }
    }

    var icon: String {
        switch self {
        case .alerts:     return "exclamationmark.triangle"
        case .appearance: return "paintbrush"
        case .network:    return "network"
        }
    }
}

// MARK: - Alerts Section

private struct AlertsSettingsSection: View {
    @Bindable var warningSettings = WarningSettings.shared

    var body: some View {
        Section {
            Picker("Alert Style", selection: Binding(
                get: { warningSettings.displayMode },
                set: { warningSettings.setDisplayMode($0) }
            )) {
                ForEach(WarningDisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(warningSettings.displayMode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Threat Alerts")
        } footer: {
            Text("Controls how Apex Flow notifies you when a system hog or unexpected outbound connection is detected.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Appearance Section

private struct AppearanceSettingsSection: View {
    @Bindable var theme = ThemeStore.shared
    private let presets = ThemePreset.allBuiltIns
    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        Section {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(presets) { preset in
                    PresetButton(
                        preset: preset,
                        isActive: theme.currentPresetID == preset.id,
                        action: { theme.applyPreset(preset) }
                    )
                }
            }
        } header: {
            Text("Presets")
        }

        Section {
            Picker("Mode", selection: $theme.appearance) {
                ForEach(ThemeStore.Appearance.allCases) { appearance in
                    Text(appearance.label).tag(appearance)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Appearance")
        }

        Section {
            ColorPicker("Accent", selection: theme.accentBinding)
            ColorPicker("Background", selection: theme.backgroundBinding)
            ColorPicker("Surface", selection: theme.surfaceBinding)
            ColorPicker("Text", selection: theme.textBinding)
            ColorPicker("Secondary Text", selection: theme.subtextBinding)
        } header: {
            Text("Colours")
        }

        Section {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                SemanticColorPicker(label: "High Load", keyPath: \.red, defaultHex: "f38ba8")
                SemanticColorPicker(label: "Medium Load", keyPath: \.yellow, defaultHex: "f9e2af")
                SemanticColorPicker(label: "Low Load", keyPath: \.green, defaultHex: "a6e3a1")
                SemanticColorPicker(label: "Blue", keyPath: \.blue, defaultHex: "89b4fa")
                SemanticColorPicker(label: "Teal", keyPath: \.teal, defaultHex: "94e2d5")
                SemanticColorPicker(label: "Sky", keyPath: \.sky, defaultHex: "89dceb")
                SemanticColorPicker(label: "Mauve", keyPath: \.mauve, defaultHex: "cba6f7")
                SemanticColorPicker(label: "Pink", keyPath: \.pink, defaultHex: "f5c2e7")
                SemanticColorPicker(label: "Peach", keyPath: \.peach, defaultHex: "fab387")
            }
        } header: {
            Text("Data Colours")
        }

        if theme.hasOverrides {
            Section {
                Button("Reset to Defaults") {
                    theme.resetColors()
                }
                .foregroundStyle(theme.red)
            }
        }

        Section {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.surface0)
                    .overlay(
                        VStack(spacing: 4) {
                            Text("Sample Panel")
                                .foregroundStyle(theme.text)
                            Text("Secondary text")
                                .font(.caption)
                                .foregroundStyle(theme.subtext0)
                            ProgressView(value: 0.6)
                                .tint(theme.accent)
                        }
                        .padding()
                    )
                    .frame(height: 120)
            }
        } header: {
            Text("Preview")
        }
    }
}

// MARK: - Network Section

private struct NetworkSettingsSection: View {
    @Bindable var leakData = NetworkLeakData.shared

    var body: some View {
        Section {
            Toggle(
                "Monitor outbound WAN connections",
                isOn: Binding(
                    get: { leakData.isEnabled },
                    set: { leakData.setEnabled($0) }
                )
            )
            Text("Detect when apps connect to the public internet. Disable this if you only want local network monitoring.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("WAN Leak Monitor")
        }

        Section {
            Toggle(
                "Ignore private traffic",
                isOn: Binding(
                    get: { leakData.ignoredPrivate },
                    set: { leakData.setIgnorePrivate($0) }
                )
            )
            Text("Skip connections to local/private IP ranges (192.168.x.x, 10.x.x.x, etc.).")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Filtering")
        }
    }
}

// MARK: - Reusable Views

private struct SemanticColorPicker: View {
    let label: String
    let keyPath: WritableKeyPath<SemanticPalette, String?>
    let defaultHex: String

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        ColorPicker(label, selection: theme.semanticColorBinding(for: keyPath, default: Color(hex: defaultHex)))
    }
}

private struct PresetButton: View {
    let preset: ThemePreset
    let isActive: Bool
    let action: () -> Void

    @Environment(ThemeStore.self) private var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(preset.background.flatMap(Color.init(hex:)) ?? theme.base)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isActive ? theme.accent : Color.clear, lineWidth: 2)
                    )
                    .overlay(
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(preset.surface.flatMap(Color.init(hex:)) ?? theme.surface0)
                                .frame(height: 14)
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(preset.accent.flatMap(Color.init(hex:)) ?? theme.accent)
                                    .frame(width: 8, height: 8)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(preset.text.flatMap(Color.init(hex:)) ?? theme.text)
                                    .frame(width: 28, height: 6)
                            }
                        }
                        .padding(8)
                    )
                    .frame(height: 64)

                Text(preset.name)
                    .font(.system(size: 10, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 28)
            }
        }
        .buttonStyle(.plain)
        .help(preset.description ?? preset.name)
    }
}
