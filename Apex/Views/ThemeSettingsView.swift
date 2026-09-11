import SwiftUI

// MARK: - Theme Settings View
/// Lets the user customise Apex Flow's appearance: light/dark mode, accent,
/// background, surface, and text colors.
struct ThemeSettingsView: View {
    @Bindable var theme = ThemeStore.shared
    @Environment(\.dismiss) private var dismiss

    private let presets = ThemePreset.allBuiltIns
    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        NavigationStack {
            Form {
                Section("Presets") {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(presets) { preset in
                            PresetButton(
                                preset: preset,
                                isActive: theme.currentPresetID == preset.id,
                                action: { theme.applyPreset(preset) }
                            )
                        }
                    }
                }

                Section("Appearance") {
                    Picker("Mode", selection: $theme.appearance) {
                        ForEach(ThemeStore.Appearance.allCases) { appearance in
                            Text(appearance.label).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Colors") {
                    ColorPicker("Accent", selection: theme.accentBinding)
                    ColorPicker("Background", selection: theme.backgroundBinding)
                    ColorPicker("Surface", selection: theme.surfaceBinding)
                    ColorPicker("Text", selection: theme.textBinding)
                    ColorPicker("Secondary Text", selection: theme.subtextBinding)
                }

                Section("Data Colors") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        semanticColorPicker("High Load", for: \.red, default: "f38ba8")
                        semanticColorPicker("Medium Load", for: \.yellow, default: "f9e2af")
                        semanticColorPicker("Low Load", for: \.green, default: "a6e3a1")
                        semanticColorPicker("Blue", for: \.blue, default: "89b4fa")
                        semanticColorPicker("Teal", for: \.teal, default: "94e2d5")
                        semanticColorPicker("Sky", for: \.sky, default: "89dceb")
                        semanticColorPicker("Mauve", for: \.mauve, default: "cba6f7")
                        semanticColorPicker("Pink", for: \.pink, default: "f5c2e7")
                        semanticColorPicker("Peach", for: \.peach, default: "fab387")
                    }
                }

                if theme.hasOverrides {
                    Section {
                        Button("Reset to Defaults") {
                            theme.resetColors()
                        }
                        .foregroundStyle(theme.red)
                    }
                }

                Section("Preview") {
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
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Theme")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 520)
    }
}

// MARK: - Preset button

private extension ThemeSettingsView {
    func semanticColorPicker(
        _ label: String,
        for keyPath: WritableKeyPath<SemanticPalette, String?>,
        default hex: String
    ) -> some View {
        ColorPicker(label, selection: theme.semanticColorBinding(for: keyPath, default: Color(hex: hex)))
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
