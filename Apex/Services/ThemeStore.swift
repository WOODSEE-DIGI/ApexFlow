import SwiftUI
import AppKit

// MARK: - Apex Theme Store
/// User-customizable UI theme for Apex Flow.
///
/// Provides the same Catppuccin/Mocha palette the app has always used, but
/// allows the user to override accent, background, surface, and text colors.
/// The store is injected into the SwiftUI environment so every panel reads
/// from the same source of truth.
@Observable
@MainActor
final class ThemeStore {
    static let shared = ThemeStore()

    enum Appearance: String, CaseIterable, Identifiable, Codable {
        case system, light, dark
        var id: String { rawValue }
        var label: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    // MARK: - Keys
    static let appearanceKey = "apex.theme.appearance"
    static let accentKey = "apex.theme.accentHex"
    static let backgroundKey = "apex.theme.backgroundHex"
    static let surfaceKey = "apex.theme.surfaceHex"
    static let textKey = "apex.theme.textHex"
    static let subtextKey = "apex.theme.subtextHex"
    static let semanticKey = "apex.theme.semanticJSON"
    static let currentPresetKey = "apex.theme.currentPresetID"

    // MARK: - Overrides
    var appearance: Appearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey)
            Self.applyAppAppearance(appearance)
        }
    }

    private var accentOverride: Color?
    private var backgroundOverride: Color?
    private var surfaceOverride: Color?
    private var textOverride: Color?
    private var subtextOverride: Color?
    private var semanticOverrides = SemanticPalette()

    /// Identifier of the last-applied built-in preset, if any. Purely cosmetic
    /// so the UI can highlight the active preset; manual tweaks clear it.
    private(set) var currentPresetID: String? {
        didSet { UserDefaults.standard.set(currentPresetID, forKey: Self.currentPresetKey) }
    }

    private init() {
        let defaults = UserDefaults.standard
        appearance = Appearance(rawValue: defaults.string(forKey: Self.appearanceKey) ?? "") ?? .system
        // Do NOT call applyAppAppearance here — NSApp may not be initialized
        // yet during @State construction in the App struct. The view layer
        // calls applyInitialAppearance() once the app lifecycle is ready.
        accentOverride = defaults.string(forKey: Self.accentKey).flatMap(Color.init(hex:))
        backgroundOverride = defaults.string(forKey: Self.backgroundKey).flatMap(Color.init(hex:))
        surfaceOverride = defaults.string(forKey: Self.surfaceKey).flatMap(Color.init(hex:))
        textOverride = defaults.string(forKey: Self.textKey).flatMap(Color.init(hex:))
        subtextOverride = defaults.string(forKey: Self.subtextKey).flatMap(Color.init(hex:))
        currentPresetID = defaults.string(forKey: Self.currentPresetKey)
        if let data = defaults.data(forKey: Self.semanticKey),
           let decoded = try? JSONDecoder().decode(SemanticPalette.self, from: data) {
            semanticOverrides = decoded
        }
        if let data = defaults.data(forKey: Self.panelAccentsKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            panelAccentOverrides = decoded.compactMapValues(Color.init(hex:))
        }
    }

    /// Applies the current appearance to NSApp. Must be called after the app
    /// lifecycle has started (e.g., from a view .task / .onAppear).
    func applyInitialAppearance() {
        Self.applyAppAppearance(appearance)
    }

    static func applyAppAppearance(_ appearance: Appearance) {
        switch appearance {
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system: NSApp.appearance = nil
        }
    }

    // MARK: - Effective colors

    /// Window / base background.
    var base: Color { backgroundOverride ?? Color(hex: "1e1e2e") }
    /// Panel surface background.
    var surface0: Color { surfaceOverride ?? Color(hex: "313244") }
    var surface1: Color { (surfaceOverride ?? Color(hex: "313244")).opacity(0.6) }
    var surface2: Color { surfaceOverride ?? Color(hex: "45475a") }

    /// Primary text.
    var text: Color { textOverride ?? Color(hex: "cdd6f4") }
    /// Secondary / muted text.
    var subtext1: Color { subtextOverride ?? Color(hex: "bac2de") }
    var subtext0: Color { subtextOverride ?? Color(hex: "a6adc8") }
    var overlay0: Color { subtextOverride?.opacity(0.7) ?? Color(hex: "6c7086") }

    /// Shared accent (used when a panel has no custom color).
    var accent: Color { accentOverride ?? Color(hex: "89b4fa") }

    /// Semantic colors derived from the accent, or fixed defaults when no
    /// override is active.
    var blue: Color { semanticOverrides.blue.flatMap(Color.init(hex:)) ?? (accentOverride ?? Color(hex: "89b4fa")) }
    var lavender: Color { semanticOverrides.lavender.flatMap(Color.init(hex:)) ?? Color(hex: "b4befe") }
    var mauve: Color { semanticOverrides.mauve.flatMap(Color.init(hex:)) ?? Color(hex: "cba6f7") }
    var pink: Color { semanticOverrides.pink.flatMap(Color.init(hex:)) ?? Color(hex: "f5c2e7") }
    var red: Color { semanticOverrides.red.flatMap(Color.init(hex:)) ?? Color(hex: "f38ba8") }
    var maroon: Color { semanticOverrides.maroon.flatMap(Color.init(hex:)) ?? Color(hex: "eba0ac") }
    var peach: Color { semanticOverrides.peach.flatMap(Color.init(hex:)) ?? Color(hex: "fab387") }
    var yellow: Color { semanticOverrides.yellow.flatMap(Color.init(hex:)) ?? Color(hex: "f9e2af") }
    var green: Color { semanticOverrides.green.flatMap(Color.init(hex:)) ?? Color(hex: "a6e3a1") }
    var teal: Color { semanticOverrides.teal.flatMap(Color.init(hex:)) ?? Color(hex: "94e2d5") }
    var sky: Color { semanticOverrides.sky.flatMap(Color.init(hex:)) ?? Color(hex: "89dceb") }
    var sapphire: Color { semanticOverrides.sapphire.flatMap(Color.init(hex:)) ?? Color(hex: "74c7ec") }

    // MARK: - Semantic accessors for panel categories
    func semanticColor(_ keyPath: KeyPath<SemanticPalette, String?>, default defaultColor: @autoclosure () -> Color) -> Color {
        semanticOverrides[keyPath: keyPath].flatMap(Color.init(hex:)) ?? defaultColor()
    }

    // MARK: - Panel accents

    private var panelAccentOverrides: [String: Color] = [:]
    private static let panelAccentsKey = "apex.theme.panelAccentsJSON"

    func panelAccent(for kind: ApexPanelKind) -> Color {
        panelAccentOverrides[kind.rawValue] ?? accent
    }

    func panelAccentBinding(for kind: ApexPanelKind) -> Binding<Color> {
        Binding(
            get: { self.panelAccent(for: kind) },
            set: { self.setPanelAccent($0, for: kind) }
        )
    }

    func setPanelAccent(_ color: Color?, for kind: ApexPanelKind) {
        panelAccentOverrides[kind.rawValue] = color
        persistPanelAccents()
    }

    private func persistPanelAccents() {
        let hexByKey = panelAccentOverrides.compactMapValues(\.hexRGBA)
        if let data = try? JSONEncoder().encode(hexByKey) {
            UserDefaults.standard.set(data, forKey: Self.panelAccentsKey)
        }
    }

    // MARK: - Bindings

    var accentBinding: Binding<Color> { binding(for: \.accent, setAccent) }
    var backgroundBinding: Binding<Color> { binding(for: \.base, setBackground) }
    var surfaceBinding: Binding<Color> { binding(for: \.surface0, setSurface) }
    var textBinding: Binding<Color> { binding(for: \.text, setText) }
    var subtextBinding: Binding<Color> { binding(for: \.subtext1, setSubtext) }

    private func binding(for keyPath: KeyPath<ThemeStore, Color>, _ setter: @escaping (Color) -> Void) -> Binding<Color> {
        Binding(get: { self[keyPath: keyPath] }, set: setter)
    }

    func setAccent(_ color: Color) { accentOverride = color; persist(Self.accentKey, color) }
    func setBackground(_ color: Color) { backgroundOverride = color; persist(Self.backgroundKey, color) }
    func setSurface(_ color: Color) { surfaceOverride = color; persist(Self.surfaceKey, color) }
    func setText(_ color: Color) { textOverride = color; persist(Self.textKey, color) }
    func setSubtext(_ color: Color) { subtextOverride = color; persist(Self.subtextKey, color) }

    func resetColors() {
        accentOverride = nil
        backgroundOverride = nil
        surfaceOverride = nil
        textOverride = nil
        subtextOverride = nil
        semanticOverrides = SemanticPalette()
        panelAccentOverrides = [:]
        currentPresetID = nil
        for key in [Self.accentKey, Self.backgroundKey, Self.surfaceKey, Self.textKey, Self.subtextKey, Self.semanticKey, Self.panelAccentsKey, Self.currentPresetKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Presets

    func applyPreset(_ preset: ThemePreset) {
        // Clear existing overrides so the preset is applied atomically.
        accentOverride = nil
        backgroundOverride = nil
        surfaceOverride = nil
        textOverride = nil
        subtextOverride = nil
        semanticOverrides = SemanticPalette()
        panelAccentOverrides = [:]

        if preset.appearance != .system {
            appearance = preset.appearance
        }
        if let hex = preset.accent {
            let color = Color(hex: hex)
            accentOverride = color
            persist(Self.accentKey, color)
        }
        if let hex = preset.background {
            let color = Color(hex: hex)
            backgroundOverride = color
            persist(Self.backgroundKey, color)
        }
        if let hex = preset.surface {
            let color = Color(hex: hex)
            surfaceOverride = color
            persist(Self.surfaceKey, color)
        }
        if let hex = preset.text {
            let color = Color(hex: hex)
            textOverride = color
            persist(Self.textKey, color)
        }
        if let hex = preset.subtext {
            let color = Color(hex: hex)
            subtextOverride = color
            persist(Self.subtextKey, color)
        }
        if let semantic = preset.semantic {
            semanticOverrides = semantic
            persistSemantic()
        }
        // Always clear persisted panel accents first, then re-write only if the
        // preset defines them. Otherwise a previous theme's accents can leak back
        // on the next launch.
        UserDefaults.standard.removeObject(forKey: Self.panelAccentsKey)
        if let accents = preset.panelAccents {
            for (kind, hex) in accents {
                panelAccentOverrides[kind.rawValue] = Color(hex: hex)
            }
            persistPanelAccents()
        }
        currentPresetID = preset.id
    }

    private func persistSemantic() {
        if let data = try? JSONEncoder().encode(semanticOverrides) {
            UserDefaults.standard.set(data, forKey: Self.semanticKey)
        }
    }

    /// Binding for a single semantic palette color. Reads from the override if
    /// set, otherwise from the supplied default, and persists any user change.
    func semanticColorBinding(
        for keyPath: WritableKeyPath<SemanticPalette, String?>,
        default defaultColor: Color
    ) -> Binding<Color> {
        Binding(
            get: { self.semanticOverrides[keyPath: keyPath].flatMap(Color.init(hex:)) ?? defaultColor },
            set: { newColor in
                self.semanticOverrides[keyPath: keyPath] = newColor.hexRGBA
                self.persistSemantic()
            }
        )
    }

    var hasOverrides: Bool {
        accentOverride != nil || backgroundOverride != nil || surfaceOverride != nil
            || textOverride != nil || subtextOverride != nil || !panelAccentOverrides.isEmpty
            || semanticOverrides != SemanticPalette()
    }

    // MARK: - Helpers

    private func persist(_ key: String, _ color: Color) {
        if let hex = color.hexRGBA { UserDefaults.standard.set(hex, forKey: key) }
    }

    /// Load gradient from green → yellow → red for load bars.
    func loadColor(_ value: Double) -> Color {
        switch value {
        case 0..<0.5: return green
        case 0.5..<0.8: return yellow
        default: return red
        }
    }
}

// MARK: - Color hex helpers

extension Color {
    /// Parse a 6-digit `RRGGBB` or 8-digit `RRGGBBAA` hex string (leading `#` optional).
    /// Returns black if the string is invalid.
    init(hex: String) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }
        if string.count == 8, let value = UInt64(string, radix: 16) {
            self = Color(
                .sRGB,
                red: Double((value >> 24) & 0xFF) / 255,
                green: Double((value >> 16) & 0xFF) / 255,
                blue: Double((value >> 8) & 0xFF) / 255,
                opacity: Double(value & 0xFF) / 255)
        } else if string.count == 6, let value = UInt64(string, radix: 16) {
            self = Color(
                .sRGB,
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255,
                opacity: 1.0)
        } else {
            self = .black
        }
    }

    var hexRGBA: String? {
        guard let resolved = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = UInt8((resolved.redComponent * 255).rounded())
        let g = UInt8((resolved.greenComponent * 255).rounded())
        let b = UInt8((resolved.blueComponent * 255).rounded())
        let a = UInt8((resolved.alphaComponent * 255).rounded())
        return String(format: "%02X%02X%02X%02X", r, g, b, a)
    }
}
