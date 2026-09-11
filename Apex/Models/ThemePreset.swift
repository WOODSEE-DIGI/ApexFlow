import SwiftUI

// MARK: - Apex Theme Preset
/// A named color theme ("skin") that can be applied to Apex Flow. Presets map
/// SwiftMaestro's richer skin format onto Apex's smaller palette, plus a
/// semantic color palette so panel-specific accents (CPU, memory, network, ...)
/// change with the theme.
struct ThemePreset: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var description: String?
    var appearance: ThemeStore.Appearance

    // Core overrides
    var accent: String?
    var background: String?
    var surface: String?
    var text: String?
    var subtext: String?

    // Semantic palette overrides (optional — nil keys fall back to defaults).
    var semantic: SemanticPalette?

    // Per-panel accent overrides.
    var panelAccents: [ApexPanelKind: String]?

    init(
        id: String? = nil,
        name: String,
        description: String? = nil,
        appearance: ThemeStore.Appearance,
        accent: String? = nil,
        background: String? = nil,
        surface: String? = nil,
        text: String? = nil,
        subtext: String? = nil,
        semantic: SemanticPalette? = nil,
        panelAccents: [ApexPanelKind: String]? = nil
    ) {
        self.id = id ?? name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
        self.name = name
        self.description = description
        self.appearance = appearance
        self.accent = accent
        self.background = background
        self.surface = surface
        self.text = text
        self.subtext = subtext
        self.semantic = semantic
        self.panelAccents = panelAccents
    }

    /// The default system look — no overrides at all.
    static var `default`: ThemePreset {
        ThemePreset(
            id: "default",
            name: "System Default",
            description: "Follows the system accent and the built-in Catppuccin palette.",
            appearance: .system
        )
    }
}

// MARK: - Semantic palette

struct SemanticPalette: Codable, Hashable {
    var blue: String?
    var lavender: String?
    var mauve: String?
    var pink: String?
    var red: String?
    var maroon: String?
    var peach: String?
    var yellow: String?
    var green: String?
    var teal: String?
    var sky: String?
    var sapphire: String?

    var cpu: String?
    var mem: String?
    var diskRead: String?
    var diskWrite: String?
    var netDown: String?
    var netUp: String?
    var wifi: String?
    var bt: String?
    var tb: String?
    var usb: String?
    var proc: String?
    var ai: String?
}

// MARK: - Built-in presets

extension ThemePreset {
    static var allBuiltIns: [ThemePreset] {
        [
            .default,
            .matrixDark,
            .matrixLight,
            .cyberpunkNeonDark,
            .cyberpunkNeonLight,
            .rainbowsAndUnicornsDark,
            .rainbowsAndUnicornsLight,
            .helloKittyPinksDark,
            .helloKittyPinksLight,
            .cleanAndMinimalDark,
            .cleanAndMinimalLight,
            .professionalDark,
            .professionalLight,
            .btopTokyoNight,
            .btopNordDark,
            .btopNordLight,
            .btopSolarizedDark,
            .btopSolarizedLight,
            .btopOneDark,
            .btopMonokai,
        ]
    }

    // MARK: - Matrix

    static var matrixDark: ThemePreset {
        ThemePreset(
            id: "matrix-dark",
            name: "Matrix Dark",
            description: "Terminal green on black.",
            appearance: .dark,
            accent: "00FF41FF",
            background: "050A05FF",
            surface: "0F1F0FFF",
            text: "00FF41FF",
            subtext: "00B22DFF",
            semantic: SemanticPalette(
                red: "FF3333FF", yellow: "CCFF00FF", green: "00FF41FF",
                teal: "00F0A0FF", sky: "00FF41FF",
                cpu: "00FF41FF", mem: "00E060FF", diskRead: "00FF41FF", diskWrite: "00E060FF",
                netDown: "00FF41FF", netUp: "00E060FF", wifi: "00FF41FF", bt: "00FF41FF",
                tb: "00FF41FF", usb: "00FF41FF", proc: "00FF41FF", ai: "00FF41FF"
            )
        )
    }

    static var matrixLight: ThemePreset {
        ThemePreset(
            id: "matrix-light",
            name: "Matrix Light",
            description: "Terminal green on a clean white-green field.",
            appearance: .light,
            accent: "00B22DFF",
            background: "F0FFF4FF",
            surface: "D8F5D8FF",
            text: "004D00FF",
            subtext: "007A00FF",
            semantic: SemanticPalette(
                red: "CC0000FF", yellow: "88CC00FF", green: "00B22DFF",
                teal: "00A060FF", sky: "00B22DFF",
                cpu: "00B22DFF", mem: "00A060FF", diskRead: "00B22DFF", diskWrite: "00A060FF",
                netDown: "00B22DFF", netUp: "00A060FF", wifi: "00B22DFF", bt: "00B22DFF",
                tb: "00B22DFF", usb: "00B22DFF", proc: "00B22DFF", ai: "00B22DFF"
            )
        )
    }

    // MARK: - Cyberpunk Neon

    static var cyberpunkNeonDark: ThemePreset {
        ThemePreset(
            id: "cyberpunk-neon-dark",
            name: "Cyberpunk Neon Dark",
            description: "Hot pink and electric blue on a dark cityscape.",
            appearance: .dark,
            accent: "FF00D2FF",
            background: "120A1FFF",
            surface: "1F1135FF",
            text: "FFFFFFFF",
            subtext: "C0B0D0FF",
            semantic: SemanticPalette(
                blue: "00F0FFFF", lavender: "B85CFFFF", pink: "FF00D2FF", red: "FF0055FF",
                peach: "F5A623FF", yellow: "F5A623FF", green: "00F0FFFF", teal: "00F0FFFF",
                sky: "00F0FFFF", sapphire: "00F0FFFF",
                cpu: "00F0FFFF", mem: "B85CFFFF", diskRead: "00F0FFFF", diskWrite: "FF00D2FF",
                netDown: "00F0FFFF", netUp: "FF00D2FF", wifi: "00F0FFFF", bt: "B85CFFFF",
                tb: "F5A623FF", usb: "00F0FFFF", proc: "FF00D2FF", ai: "B85CFFFF"
            ),
            panelAccents: [
                .cpu: "00F0FFFF", .memory: "FF00D2FF", .network: "F5A623FF",
                .connectivity: "B85CFFFF", .aiModel: "00F0FFFF", .diskHealth: "FF00D2FF",
                .processes: "00F0FFFF"
            ]
        )
    }

    static var cyberpunkNeonLight: ThemePreset {
        ThemePreset(
            id: "cyberpunk-neon-light",
            name: "Cyberpunk Neon Light",
            description: "Hot pink and electric blue on a pale cityscape.",
            appearance: .light,
            accent: "FF00D2FF",
            background: "FFF5FCFF",
            surface: "F0E6FFFF",
            text: "1A0A2EFF",
            subtext: "5A4A6EFF",
            semantic: SemanticPalette(
                blue: "00B0CCFF", lavender: "B85CFFFF", pink: "FF00D2FF", red: "D00050FF",
                peach: "E09000FF", yellow: "E09000FF", green: "00B0CCFF", teal: "00B0CCFF",
                sky: "00B0CCFF", sapphire: "00B0CCFF",
                cpu: "00B0CCFF", mem: "B85CFFFF", diskRead: "00B0CCFF", diskWrite: "FF00D2FF",
                netDown: "00B0CCFF", netUp: "FF00D2FF", wifi: "00B0CCFF", bt: "B85CFFFF",
                tb: "E09000FF", usb: "00B0CCFF", proc: "FF00D2FF", ai: "B85CFFFF"
            ),
            panelAccents: [
                .cpu: "00B0CCFF", .memory: "FF00D2FF", .network: "E09000FF",
                .connectivity: "B85CFFFF", .aiModel: "00B0CCFF", .diskHealth: "FF00D2FF",
                .processes: "00B0CCFF"
            ]
        )
    }

    // MARK: - Hello Kitty Pinks

    static var helloKittyPinksLight: ThemePreset {
        ThemePreset(
            id: "hello-kitty-pinks-light",
            name: "Hello Kitty Pinks Light",
            description: "Soft pastels and candy pinks.",
            appearance: .light,
            accent: "FF1493FF",
            background: "FFF5F9FF",
            surface: "FFD1E0FF",
            text: "C2185BFF",
            subtext: "F06292FF",
            semantic: SemanticPalette(
                blue: "FF69B4FF", lavender: "DDA0DDFF", pink: "FF1493FF", red: "F06292FF",
                peach: "FFAB91FF", yellow: "FFD54FFF", green: "F48FB1FF", teal: "F48FB1FF",
                sky: "FF85C0FF", sapphire: "FF69B4FF",
                cpu: "FF69B4FF", mem: "DDA0DDFF", diskRead: "F48FB1FF", diskWrite: "FFAB91FF",
                netDown: "F48FB1FF", netUp: "FFAB91FF", wifi: "FF85C0FF", bt: "FF69B4FF",
                tb: "FFD54FFF", usb: "F48FB1FF", proc: "FF1493FF", ai: "FF85C0FF"
            ),
            panelAccents: [
                .cpu: "FF69B4FF", .memory: "DDA0DDFF", .network: "FF85C0FF",
                .connectivity: "FF1493FF", .aiModel: "F48FB1FF", .diskHealth: "F06292FF",
                .processes: "FF69B4FF"
            ]
        )
    }

    static var helloKittyPinksDark: ThemePreset {
        ThemePreset(
            id: "hello-kitty-pinks-dark",
            name: "Hello Kitty Pinks Dark",
            description: "Candy pinks on a deep magenta night.",
            appearance: .dark,
            accent: "FF69B4FF",
            background: "2A0A1AFF",
            surface: "3D0F26FF",
            text: "FFFFFFCC",
            subtext: "F8BBD0FF",
            semantic: SemanticPalette(
                blue: "FF69B4FF", lavender: "DDA0DDFF", pink: "FF69B4FF", red: "F06292FF",
                peach: "FFAB91FF", yellow: "FFD54FFF", green: "F48FB1FF", teal: "F48FB1FF",
                sky: "FF85C0FF", sapphire: "FF69B4FF",
                cpu: "FF69B4FF", mem: "DDA0DDFF", diskRead: "F48FB1FF", diskWrite: "FFAB91FF",
                netDown: "F48FB1FF", netUp: "FFAB91FF", wifi: "FF85C0FF", bt: "FF69B4FF",
                tb: "FFD54FFF", usb: "F48FB1FF", proc: "FF69B4FF", ai: "FF85C0FF"
            ),
            panelAccents: [
                .cpu: "FF69B4FF", .memory: "DDA0DDFF", .network: "FF85C0FF",
                .connectivity: "FF69B4FF", .aiModel: "F48FB1FF", .diskHealth: "F06292FF",
                .processes: "FF69B4FF"
            ]
        )
    }

    // MARK: - Rainbows and Unicorns

    static var rainbowsAndUnicornsLight: ThemePreset {
        ThemePreset(
            id: "rainbows-and-unicorns-light",
            name: "Rainbows and Unicorns Light",
            description: "Vibrant rainbow panels on a light cloud background.",
            appearance: .light,
            accent: "FF0080FF",
            background: "F8F4FFFF",
            surface: "E6F7FFFF",
            text: "1565C0FF",
            subtext: "1976D2FF",
            semantic: SemanticPalette(
                blue: "0000FFFF", lavender: "9400D3FF", pink: "FF0080FF", red: "FF0000FF",
                peach: "FF7F00FF", yellow: "FFFF00FF", green: "00FF00FF", teal: "00FFFFFF",
                sky: "00FFFFFF", sapphire: "0000FFFF",
                cpu: "FF0000FF", mem: "FF7F00FF", diskRead: "00FF00FF", diskWrite: "FFFF00FF",
                netDown: "00FFFFFF", netUp: "0000FFFF", wifi: "9400D3FF", bt: "FF0080FF",
                tb: "FF7F00FF", usb: "00FF00FF", proc: "FF0000FF", ai: "9400D3FF"
            ),
            panelAccents: [
                .cpu: "FF0000FF", .memory: "FF7F00FF", .network: "FFFF00FF",
                .connectivity: "00FF00FF", .aiModel: "0000FFFF", .diskHealth: "9400D3FF",
                .processes: "FF0080FF"
            ]
        )
    }

    static var rainbowsAndUnicornsDark: ThemePreset {
        ThemePreset(
            id: "rainbows-and-unicorns-dark",
            name: "Rainbows and Unicorns Dark",
            description: "Vibrant rainbow panels on a dark night background.",
            appearance: .dark,
            accent: "FF00A0FF",
            background: "1A0A2AFF",
            surface: "251035FF",
            text: "FFFFFFCC",
            subtext: "D0B0E0FF",
            semantic: SemanticPalette(
                blue: "3333FFFF", lavender: "CC33FFFF", pink: "FF00A0FF", red: "FF3333FF",
                peach: "FF9933FF", yellow: "FFFF33FF", green: "33FF33FF", teal: "33FFFFFF",
                sky: "33FFFFFF", sapphire: "3333FFFF",
                cpu: "FF3333FF", mem: "FF9933FF", diskRead: "33FF33FF", diskWrite: "FFFF33FF",
                netDown: "33FFFFFF", netUp: "3333FFFF", wifi: "CC33FFFF", bt: "FF00A0FF",
                tb: "FF9933FF", usb: "33FF33FF", proc: "FF3333FF", ai: "CC33FFFF"
            ),
            panelAccents: [
                .cpu: "FF3333FF", .memory: "FF9933FF", .network: "FFFF33FF",
                .connectivity: "33FF33FF", .aiModel: "3333FFFF", .diskHealth: "CC33FFFF",
                .processes: "FF00A0FF"
            ]
        )
    }

    // MARK: - Clean and Minimal

    static var cleanAndMinimalLight: ThemePreset {
        ThemePreset(
            id: "clean-and-minimal-light",
            name: "Clean and Minimal Light",
            description: "Soft grays with a restrained accent.",
            appearance: .light,
            accent: "5A7D9AFF",
            background: "F5F5F7FF",
            surface: "EBEBF0FF",
            text: "1D1D1FFF",
            subtext: "5A5A5EFF",
            semantic: SemanticPalette(
                blue: "5A7D9AFF", lavender: "8A7D9AFF", pink: "B85C9AFF", red: "D65A5AFF",
                peach: "D69E5AFF", yellow: "D6B85AFF", green: "5AA67DFF", teal: "5A9E9EFF",
                sky: "5A7D9AFF", sapphire: "5A7DB8FF",
                cpu: "5A7D9AFF", mem: "8A7D9AFF", diskRead: "5A9E9EFF", diskWrite: "D69E5AFF",
                netDown: "5AA67DFF", netUp: "D69E5AFF", wifi: "5A7D9AFF", bt: "8A7D9AFF",
                tb: "D6B85AFF", usb: "5A9E9EFF", proc: "B85C9AFF", ai: "5A7D9AFF"
            )
        )
    }

    static var cleanAndMinimalDark: ThemePreset {
        ThemePreset(
            id: "clean-and-minimal-dark",
            name: "Clean and Minimal Dark",
            description: "Soft grays with a restrained accent, dark mode.",
            appearance: .dark,
            accent: "8BA4B8FF",
            background: "1D1D1FFF",
            surface: "2C2C32FF",
            text: "FFFFFFCC",
            subtext: "A0A0A8FF",
            semantic: SemanticPalette(
                blue: "8BA4B8FF", lavender: "A08BA4FF", pink: "B88BA4FF", red: "D68888FF",
                peach: "D6B08BFF", yellow: "D6C88BFF", green: "8BB8A4FF", teal: "8BB8B8FF",
                sky: "8BA4B8FF", sapphire: "8BA4D6FF",
                cpu: "8BA4B8FF", mem: "A08BA4FF", diskRead: "8BB8B8FF", diskWrite: "D6B08BFF",
                netDown: "8BB8A4FF", netUp: "D6B08BFF", wifi: "8BA4B8FF", bt: "A08BA4FF",
                tb: "D6C88BFF", usb: "8BB8B8FF", proc: "B88BA4FF", ai: "8BA4B8FF"
            )
        )
    }

    // MARK: - Professional

    static var professionalLight: ThemePreset {
        ThemePreset(
            id: "professional-light",
            name: "Professional Light",
            description: "Navy, slate, and crisp white. Boardroom-ready.",
            appearance: .light,
            accent: "1A3C6EFF",
            background: "F7F9FCFF",
            surface: "E1E8F0FF",
            text: "1F2D3DFF",
            subtext: "4A5A6AFF",
            semantic: SemanticPalette(
                blue: "1A3C6EFF", lavender: "3C1A6EFF", pink: "6E1A3CFF", red: "8B1A1AFF",
                peach: "8B5A1AFF", yellow: "8B7B1AFF", green: "1A6E3CFF", teal: "1A6E6EFF",
                sky: "1A3C6EFF", sapphire: "1A4A8BFF",
                cpu: "1A3C6EFF", mem: "3C1A6EFF", diskRead: "1A6E6EFF", diskWrite: "8B5A1AFF",
                netDown: "1A6E3CFF", netUp: "8B5A1AFF", wifi: "1A3C6EFF", bt: "3C1A6EFF",
                tb: "8B7B1AFF", usb: "1A6E6EFF", proc: "6E1A3CFF", ai: "1A3C6EFF"
            )
        )
    }

    static var professionalDark: ThemePreset {
        ThemePreset(
            id: "professional-dark",
            name: "Professional Dark",
            description: "Navy, slate, and crisp white. Boardroom-ready.",
            appearance: .dark,
            accent: "5A8CCBFF",
            background: "0F1720FF",
            surface: "1E2D3DFF",
            text: "FFFFFFCC",
            subtext: "8A9AABFF",
            semantic: SemanticPalette(
                blue: "5A8CCBFF", lavender: "8A5ACBFF", pink: "CB5A8CFF", red: "CB5A5AFF",
                peach: "CB8B5AFF", yellow: "CBAE5AFF", green: "5ACB8CFF", teal: "5ACBCBFF",
                sky: "5A8CCBFF", sapphire: "5A8CCBFF",
                cpu: "5A8CCBFF", mem: "8A5ACBFF", diskRead: "5ACBCBFF", diskWrite: "CB8B5AFF",
                netDown: "5ACB8CFF", netUp: "CB8B5AFF", wifi: "5A8CCBFF", bt: "8A5ACBFF",
                tb: "CBAE5AFF", usb: "5ACBCBFF", proc: "CB5A8CFF", ai: "5A8CCBFF"
            )
        )
    }

    // MARK: - btop Tokyo Night

    static var btopTokyoNight: ThemePreset {
        ThemePreset(
            id: "btop-tokyo-night",
            name: "btop Tokyo Night",
            description: "Cyan highlights on the deep blue of the Tokyo night skyline.",
            appearance: .dark,
            accent: "7DCFFFFF",
            background: "1A1B26FF",
            surface: "1F2335FF",
            text: "CFC9C2FF",
            subtext: "565F89FF",
            semantic: SemanticPalette(
                blue: "7DCFFFFF", lavender: "BB9AF7FF", pink: "F7768EFF", red: "F7768EFF",
                peach: "E0AF68FF", yellow: "E0AF68FF", green: "9ECE6AFF", teal: "2AA198FF",
                sky: "7DCFFFFF", sapphire: "7AA2F7FF",
                cpu: "7DCFFFFF", mem: "BB9AF7FF", diskRead: "2AA198FF", diskWrite: "E0AF68FF",
                netDown: "9ECE6AFF", netUp: "E0AF68FF", wifi: "7DCFFFFF", bt: "BB9AF7FF",
                tb: "E0AF68FF", usb: "2AA198FF", proc: "F7768EFF", ai: "BB9AF7FF"
            ),
            panelAccents: [
                .cpu: "7DCFFFFF", .memory: "BB9AF7FF", .network: "E0AF68FF",
                .connectivity: "F7768EFF", .aiModel: "7DCFFFFF", .diskHealth: "9ECE6AFF",
                .processes: "7DCFFFFF"
            ]
        )
    }

    // MARK: - btop Nord

    static var btopNordDark: ThemePreset {
        ThemePreset(
            id: "btop-nord-dark",
            name: "btop Nord Dark",
            description: "Arctic blues and frost accents from the north.",
            appearance: .dark,
            accent: "88C0D0FF",
            background: "2E3440FF",
            surface: "3B4252FF",
            text: "D8DEE9FF",
            subtext: "4C566AFF",
            semantic: SemanticPalette(
                blue: "88C0D0FF", lavender: "B48EADFF", pink: "BF616AFF", red: "BF616AFF",
                peach: "EBCB8BFF", yellow: "EBCB8BFF", green: "A3BE8CFF", teal: "8FBCBBFF",
                sky: "88C0D0FF", sapphire: "5E81ACFF",
                cpu: "88C0D0FF", mem: "B48EADFF", diskRead: "8FBCBBFF", diskWrite: "EBCB8BFF",
                netDown: "A3BE8CFF", netUp: "EBCB8BFF", wifi: "88C0D0FF", bt: "B48EADFF",
                tb: "EBCB8BFF", usb: "8FBCBBFF", proc: "BF616AFF", ai: "B48EADFF"
            ),
            panelAccents: [
                .cpu: "88C0D0FF", .memory: "B48EADFF", .network: "EBCB8BFF",
                .connectivity: "BF616AFF", .aiModel: "88C0D0FF", .diskHealth: "A3BE8CFF",
                .processes: "88C0D0FF"
            ]
        )
    }

    static var btopNordLight: ThemePreset {
        ThemePreset(
            id: "btop-nord-light",
            name: "btop Nord Light",
            description: "Polar white fields with frost accents.",
            appearance: .light,
            accent: "5E81ACFF",
            background: "ECEFF4FF",
            surface: "D8DEE9FF",
            text: "2E3440FF",
            subtext: "4C566AFF",
            semantic: SemanticPalette(
                blue: "5E81ACFF", lavender: "B48EADFF", pink: "BF616AFF", red: "BF616AFF",
                peach: "D08770FF", yellow: "D08770FF", green: "A3BE8CFF", teal: "8FBCBBFF",
                sky: "5E81ACFF", sapphire: "5E81ACFF",
                cpu: "5E81ACFF", mem: "B48EADFF", diskRead: "8FBCBBFF", diskWrite: "D08770FF",
                netDown: "A3BE8CFF", netUp: "D08770FF", wifi: "5E81ACFF", bt: "B48EADFF",
                tb: "D08770FF", usb: "8FBCBBFF", proc: "BF616AFF", ai: "B48EADFF"
            ),
            panelAccents: [
                .cpu: "5E81ACFF", .memory: "B48EADFF", .network: "D08770FF",
                .connectivity: "BF616AFF", .aiModel: "5E81ACFF", .diskHealth: "A3BE8CFF",
                .processes: "5E81ACFF"
            ]
        )
    }

    // MARK: - btop Solarized

    static var btopSolarizedDark: ThemePreset {
        ThemePreset(
            id: "btop-solarized-dark",
            name: "btop Solarized Dark",
            description: "Ethan Schoonover's precision colors on a deep teal field.",
            appearance: .dark,
            accent: "B58900FF",
            background: "002B36FF",
            surface: "073642FF",
            text: "EEE8D5FF",
            subtext: "586E75FF",
            semantic: SemanticPalette(
                blue: "268BD2FF", lavender: "6C71C4FF", pink: "D33682FF", red: "DC322FFF",
                peach: "CB4B16FF", yellow: "B58900FF", green: "859900FF", teal: "2AA198FF",
                sky: "268BD2FF", sapphire: "268BD2FF",
                cpu: "268BD2FF", mem: "6C71C4FF", diskRead: "2AA198FF", diskWrite: "CB4B16FF",
                netDown: "859900FF", netUp: "CB4B16FF", wifi: "268BD2FF", bt: "6C71C4FF",
                tb: "B58900FF", usb: "2AA198FF", proc: "DC322FFF", ai: "6C71C4FF"
            ),
            panelAccents: [
                .cpu: "268BD2FF", .memory: "6C71C4FF", .network: "B58900FF",
                .connectivity: "DC322FFF", .aiModel: "268BD2FF", .diskHealth: "859900FF",
                .processes: "268BD2FF"
            ]
        )
    }

    static var btopSolarizedLight: ThemePreset {
        ThemePreset(
            id: "btop-solarized-light",
            name: "btop Solarized Light",
            description: "Warm paper tones with the same precision palette.",
            appearance: .light,
            accent: "B58900FF",
            background: "FDF6E3FF",
            surface: "EEE8D5FF",
            text: "586E75FF",
            subtext: "93A1A1FF",
            semantic: SemanticPalette(
                blue: "268BD2FF", lavender: "6C71C4FF", pink: "D33682FF", red: "DC322FFF",
                peach: "CB4B16FF", yellow: "B58900FF", green: "859900FF", teal: "2AA198FF",
                sky: "268BD2FF", sapphire: "268BD2FF",
                cpu: "268BD2FF", mem: "6C71C4FF", diskRead: "2AA198FF", diskWrite: "CB4B16FF",
                netDown: "859900FF", netUp: "CB4B16FF", wifi: "268BD2FF", bt: "6C71C4FF",
                tb: "B58900FF", usb: "2AA198FF", proc: "DC322FFF", ai: "6C71C4FF"
            ),
            panelAccents: [
                .cpu: "268BD2FF", .memory: "6C71C4FF", .network: "B58900FF",
                .connectivity: "DC322FFF", .aiModel: "268BD2FF", .diskHealth: "859900FF",
                .processes: "268BD2FF"
            ]
        )
    }

    // MARK: - btop One Dark

    static var btopOneDark: ThemePreset {
        ThemePreset(
            id: "btop-one-dark",
            name: "btop One Dark",
            description: "Atom's iconic editor palette, blue highlights on charcoal.",
            appearance: .dark,
            accent: "61AFEFFF",
            background: "282C34FF",
            surface: "2C313CFF",
            text: "ABB2BFFF",
            subtext: "5C6370FF",
            semantic: SemanticPalette(
                blue: "61AFEFFF", lavender: "C678DDFF", pink: "E06C75FF", red: "E06C75FF",
                peach: "E5C07BFF", yellow: "E5C07BFF", green: "98C379FF", teal: "56B6C2FF",
                sky: "61AFEFFF", sapphire: "61AFEFFF",
                cpu: "61AFEFFF", mem: "C678DDFF", diskRead: "56B6C2FF", diskWrite: "E5C07BFF",
                netDown: "98C379FF", netUp: "E5C07BFF", wifi: "61AFEFFF", bt: "C678DDFF",
                tb: "E5C07BFF", usb: "56B6C2FF", proc: "E06C75FF", ai: "C678DDFF"
            ),
            panelAccents: [
                .cpu: "61AFEFFF", .memory: "C678DDFF", .network: "E5C07BFF",
                .connectivity: "E06C75FF", .aiModel: "61AFEFFF", .diskHealth: "98C379FF",
                .processes: "61AFEFFF"
            ]
        )
    }

    // MARK: - btop Monokai

    static var btopMonokai: ThemePreset {
        ThemePreset(
            id: "btop-monokai",
            name: "btop Monokai",
            description: "Hot pink and lime on near-black, straight from the editor classic.",
            appearance: .dark,
            accent: "F92672FF",
            background: "121310FF",
            surface: "1E1F1CFF",
            text: "F8F8F2FF",
            subtext: "75715EFF",
            semantic: SemanticPalette(
                blue: "66D9EFFF", lavender: "AE81FFFF", pink: "F92672FF", red: "F92672FF",
                peach: "FD971FFF", yellow: "E6DB74FF", green: "A6E22EFF", teal: "66D9EFFF",
                sky: "66D9EFFF", sapphire: "66D9EFFF",
                cpu: "66D9EFFF", mem: "AE81FFFF", diskRead: "66D9EFFF", diskWrite: "FD971FFF",
                netDown: "A6E22EFF", netUp: "FD971FFF", wifi: "66D9EFFF", bt: "AE81FFFF",
                tb: "E6DB74FF", usb: "66D9EFFF", proc: "F92672FF", ai: "AE81FFFF"
            ),
            panelAccents: [
                .cpu: "66D9EFFF", .memory: "AE81FFFF", .network: "E6DB74FF",
                .connectivity: "F92672FF", .aiModel: "66D9EFFF", .diskHealth: "A6E22EFF",
                .processes: "66D9EFFF"
            ]
        )
    }
}
