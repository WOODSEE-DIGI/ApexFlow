import SwiftUI

// MARK: - Apex Theme Swatch Collection
/// Every color used by Apex Flow's built-in themes and skins, exported as a
/// standalone, copy-paste-friendly palette collection. Drop this file into any
/// macOS/iOS SwiftUI app to reuse the same colors.
///
/// Generated from:
///   - Apex/Shared/Theme.swift
///   - Apex/Services/ThemeStore.swift
///   - Apex/Models/ThemePreset.swift
public enum ApexThemeSwatches {
    // MARK: - Types

    public struct Palette: Identifiable, Hashable, Sendable {
        public let id: String
        public let name: String
        public let description: String
        public let appearance: Appearance
        public let swatches: [Swatch]
        public var idColor: Color { Color(hex: swatches.first?.hex ?? "000000FF") }
    }

    public struct Swatch: Identifiable, Hashable, Sendable {
        public let id: String
        public let names: [String]
        public let hex: String

        public init(names: [String], hex: String) {
            self.names = names
            self.hex = hex
            self.id = "\(hex)_\(names.joined(separator: ","))"
        }

        public var name: String { names.joined(separator: ", ") }
        public var color: Color { Color(hex: hex) }
    }

    public enum Appearance: String, Sendable, CaseIterable {
        case system, light, dark
    }

    // MARK: - Palettes

    // MARK: - System Default
    public static let systemDefault = Palette(
        id: "system-default",
        name: "System Default",
        description: "Follows the system accent and the built-in Catppuccin/Mocha palette.",
        appearance: .system,
        swatches: [
            Swatch(names: ["Base"], hex: "1E1E2EFF"),
            Swatch(names: ["Mantle"], hex: "181825FF"),
            Swatch(names: ["Crust"], hex: "11111BFF"),
            Swatch(names: ["Surface 0"], hex: "313244FF"),
            Swatch(names: ["Surface 1 (60%)"], hex: "31324499"),
            Swatch(names: ["Surface 2"], hex: "45475AFF"),
            Swatch(names: ["Text"], hex: "CDD6F4FF"),
            Swatch(names: ["Subtext 1"], hex: "BAC2DEFF"),
            Swatch(names: ["Subtext 0"], hex: "A6ADC8FF"),
            Swatch(names: ["Overlay 0"], hex: "6C7086FF"),
            Swatch(names: ["Accent"], hex: "89B4FAFF"),
            Swatch(names: ["Blue"], hex: "89B4FAFF"),
            Swatch(names: ["Lavender"], hex: "B4BEFEFF"),
            Swatch(names: ["Mauve"], hex: "CBA6F7FF"),
            Swatch(names: ["Pink"], hex: "F5C2E7FF"),
            Swatch(names: ["Red"], hex: "F38BA8FF"),
            Swatch(names: ["Maroon"], hex: "EBA0ACFF"),
            Swatch(names: ["Peach"], hex: "FAB387FF"),
            Swatch(names: ["Yellow"], hex: "F9E2AFFF"),
            Swatch(names: ["Green"], hex: "A6E3A1FF"),
            Swatch(names: ["Teal"], hex: "94E2D5FF"),
            Swatch(names: ["Sky"], hex: "89DCEBFF"),
            Swatch(names: ["Sapphire"], hex: "74C7ECFF")
        ]
    )
    // MARK: - Matrix Dark
    public static let matrixDark = Palette(
        id: "matrix-dark",
        name: "Matrix Dark",
        description: "Terminal green on black.",
        appearance: .dark,
        swatches: [
            Swatch(names: ["Accent"], hex: "00FF41FF"),
            Swatch(names: ["Background"], hex: "050A05FF"),
            Swatch(names: ["Surface"], hex: "0F1F0FFF"),
            Swatch(names: ["Text"], hex: "00FF41FF"),
            Swatch(names: ["Subtext"], hex: "00B22DFF"),
            Swatch(names: ["red"], hex: "FF3333FF"),
            Swatch(names: ["yellow"], hex: "CCFF00FF"),
            Swatch(names: ["green"], hex: "00FF41FF"),
            Swatch(names: ["teal"], hex: "00F0A0FF"),
            Swatch(names: ["sky"], hex: "00FF41FF"),
            Swatch(names: ["cpu"], hex: "00FF41FF"),
            Swatch(names: ["mem"], hex: "00E060FF"),
            Swatch(names: ["diskRead"], hex: "00FF41FF"),
            Swatch(names: ["diskWrite"], hex: "00E060FF"),
            Swatch(names: ["netDown"], hex: "00FF41FF"),
            Swatch(names: ["netUp"], hex: "00E060FF"),
            Swatch(names: ["wifi"], hex: "00FF41FF"),
            Swatch(names: ["bt"], hex: "00FF41FF"),
            Swatch(names: ["tb"], hex: "00FF41FF"),
            Swatch(names: ["usb"], hex: "00FF41FF"),
            Swatch(names: ["proc"], hex: "00FF41FF"),
            Swatch(names: ["ai"], hex: "00FF41FF")
        ]
    )
    // MARK: - Matrix Light
    public static let matrixLight = Palette(
        id: "matrix-light",
        name: "Matrix Light",
        description: "Terminal green on a clean white-green field.",
        appearance: .light,
        swatches: [
            Swatch(names: ["Accent"], hex: "00B22DFF"),
            Swatch(names: ["Background"], hex: "F0FFF4FF"),
            Swatch(names: ["Surface"], hex: "D8F5D8FF"),
            Swatch(names: ["Text"], hex: "004D00FF"),
            Swatch(names: ["Subtext"], hex: "007A00FF"),
            Swatch(names: ["red"], hex: "CC0000FF"),
            Swatch(names: ["yellow"], hex: "88CC00FF"),
            Swatch(names: ["green"], hex: "00B22DFF"),
            Swatch(names: ["teal"], hex: "00A060FF"),
            Swatch(names: ["sky"], hex: "00B22DFF"),
            Swatch(names: ["cpu"], hex: "00B22DFF"),
            Swatch(names: ["mem"], hex: "00A060FF"),
            Swatch(names: ["diskRead"], hex: "00B22DFF"),
            Swatch(names: ["diskWrite"], hex: "00A060FF"),
            Swatch(names: ["netDown"], hex: "00B22DFF"),
            Swatch(names: ["netUp"], hex: "00A060FF"),
            Swatch(names: ["wifi"], hex: "00B22DFF"),
            Swatch(names: ["bt"], hex: "00B22DFF"),
            Swatch(names: ["tb"], hex: "00B22DFF"),
            Swatch(names: ["usb"], hex: "00B22DFF"),
            Swatch(names: ["proc"], hex: "00B22DFF"),
            Swatch(names: ["ai"], hex: "00B22DFF")
        ]
    )
    // MARK: - Cyberpunk Neon Dark
    public static let cyberpunkNeonDark = Palette(
        id: "cyberpunk-neon-dark",
        name: "Cyberpunk Neon Dark",
        description: "Hot pink and electric blue on a dark cityscape.",
        appearance: .dark,
        swatches: [
            Swatch(names: ["Accent"], hex: "FF00D2FF"),
            Swatch(names: ["Background"], hex: "120A1FFF"),
            Swatch(names: ["Surface"], hex: "1F1135FF"),
            Swatch(names: ["Text"], hex: "FFFFFFFF"),
            Swatch(names: ["Subtext"], hex: "C0B0D0FF"),
            Swatch(names: ["blue"], hex: "00F0FFFF"),
            Swatch(names: ["lavender"], hex: "B85CFFFF"),
            Swatch(names: ["pink"], hex: "FF00D2FF"),
            Swatch(names: ["red"], hex: "FF0055FF"),
            Swatch(names: ["peach"], hex: "F5A623FF"),
            Swatch(names: ["yellow"], hex: "F5A623FF"),
            Swatch(names: ["green"], hex: "00F0FFFF"),
            Swatch(names: ["teal"], hex: "00F0FFFF"),
            Swatch(names: ["sky"], hex: "00F0FFFF"),
            Swatch(names: ["sapphire"], hex: "00F0FFFF"),
            Swatch(names: ["cpu"], hex: "00F0FFFF"),
            Swatch(names: ["mem"], hex: "B85CFFFF"),
            Swatch(names: ["diskRead"], hex: "00F0FFFF"),
            Swatch(names: ["diskWrite"], hex: "FF00D2FF"),
            Swatch(names: ["netDown"], hex: "00F0FFFF"),
            Swatch(names: ["netUp"], hex: "FF00D2FF"),
            Swatch(names: ["wifi"], hex: "00F0FFFF"),
            Swatch(names: ["bt"], hex: "B85CFFFF"),
            Swatch(names: ["tb"], hex: "F5A623FF"),
            Swatch(names: ["usb"], hex: "00F0FFFF"),
            Swatch(names: ["proc"], hex: "FF00D2FF"),
            Swatch(names: ["ai"], hex: "B85CFFFF"),
            Swatch(names: ["cpu"], hex: "00F0FFFF"),
            Swatch(names: ["memory"], hex: "FF00D2FF"),
            Swatch(names: ["network"], hex: "F5A623FF"),
            Swatch(names: ["connectivity"], hex: "B85CFFFF"),
            Swatch(names: ["aiModel"], hex: "00F0FFFF"),
            Swatch(names: ["diskHealth"], hex: "FF00D2FF"),
            Swatch(names: ["processes"], hex: "00F0FFFF")
        ]
    )
    // MARK: - Cyberpunk Neon Light
    public static let cyberpunkNeonLight = Palette(
        id: "cyberpunk-neon-light",
        name: "Cyberpunk Neon Light",
        description: "Hot pink and electric blue on a pale cityscape.",
        appearance: .light,
        swatches: [
            Swatch(names: ["Accent"], hex: "FF00D2FF"),
            Swatch(names: ["Background"], hex: "FFF5FCFF"),
            Swatch(names: ["Surface"], hex: "F0E6FFFF"),
            Swatch(names: ["Text"], hex: "1A0A2EFF"),
            Swatch(names: ["Subtext"], hex: "5A4A6EFF"),
            Swatch(names: ["blue"], hex: "00B0CCFF"),
            Swatch(names: ["lavender"], hex: "B85CFFFF"),
            Swatch(names: ["pink"], hex: "FF00D2FF"),
            Swatch(names: ["red"], hex: "D00050FF"),
            Swatch(names: ["peach"], hex: "E09000FF"),
            Swatch(names: ["yellow"], hex: "E09000FF"),
            Swatch(names: ["green"], hex: "00B0CCFF"),
            Swatch(names: ["teal"], hex: "00B0CCFF"),
            Swatch(names: ["sky"], hex: "00B0CCFF"),
            Swatch(names: ["sapphire"], hex: "00B0CCFF"),
            Swatch(names: ["cpu"], hex: "00B0CCFF"),
            Swatch(names: ["mem"], hex: "B85CFFFF"),
            Swatch(names: ["diskRead"], hex: "00B0CCFF"),
            Swatch(names: ["diskWrite"], hex: "FF00D2FF"),
            Swatch(names: ["netDown"], hex: "00B0CCFF"),
            Swatch(names: ["netUp"], hex: "FF00D2FF"),
            Swatch(names: ["wifi"], hex: "00B0CCFF"),
            Swatch(names: ["bt"], hex: "B85CFFFF"),
            Swatch(names: ["tb"], hex: "E09000FF"),
            Swatch(names: ["usb"], hex: "00B0CCFF"),
            Swatch(names: ["proc"], hex: "FF00D2FF"),
            Swatch(names: ["ai"], hex: "B85CFFFF"),
            Swatch(names: ["cpu"], hex: "00B0CCFF"),
            Swatch(names: ["memory"], hex: "FF00D2FF"),
            Swatch(names: ["network"], hex: "E09000FF"),
            Swatch(names: ["connectivity"], hex: "B85CFFFF"),
            Swatch(names: ["aiModel"], hex: "00B0CCFF"),
            Swatch(names: ["diskHealth"], hex: "FF00D2FF"),
            Swatch(names: ["processes"], hex: "00B0CCFF")
        ]
    )
    // MARK: - Hello Kitty Pinks Light
    public static let helloKittyPinksLight = Palette(
        id: "hello-kitty-pinks-light",
        name: "Hello Kitty Pinks Light",
        description: "Soft pastels and candy pinks.",
        appearance: .light,
        swatches: [
            Swatch(names: ["Accent"], hex: "FF1493FF"),
            Swatch(names: ["Background"], hex: "FFF5F9FF"),
            Swatch(names: ["Surface"], hex: "FFD1E0FF"),
            Swatch(names: ["Text"], hex: "C2185BFF"),
            Swatch(names: ["Subtext"], hex: "F06292FF"),
            Swatch(names: ["blue"], hex: "FF69B4FF"),
            Swatch(names: ["lavender"], hex: "DDA0DDFF"),
            Swatch(names: ["pink"], hex: "FF1493FF"),
            Swatch(names: ["red"], hex: "F06292FF"),
            Swatch(names: ["peach"], hex: "FFAB91FF"),
            Swatch(names: ["yellow"], hex: "FFD54FFF"),
            Swatch(names: ["green"], hex: "F48FB1FF"),
            Swatch(names: ["teal"], hex: "F48FB1FF"),
            Swatch(names: ["sky"], hex: "FF85C0FF"),
            Swatch(names: ["sapphire"], hex: "FF69B4FF"),
            Swatch(names: ["cpu"], hex: "FF69B4FF"),
            Swatch(names: ["mem"], hex: "DDA0DDFF"),
            Swatch(names: ["diskRead"], hex: "F48FB1FF"),
            Swatch(names: ["diskWrite"], hex: "FFAB91FF"),
            Swatch(names: ["netDown"], hex: "F48FB1FF"),
            Swatch(names: ["netUp"], hex: "FFAB91FF"),
            Swatch(names: ["wifi"], hex: "FF85C0FF"),
            Swatch(names: ["bt"], hex: "FF69B4FF"),
            Swatch(names: ["tb"], hex: "FFD54FFF"),
            Swatch(names: ["usb"], hex: "F48FB1FF"),
            Swatch(names: ["proc"], hex: "FF1493FF"),
            Swatch(names: ["ai"], hex: "FF85C0FF"),
            Swatch(names: ["cpu"], hex: "FF69B4FF"),
            Swatch(names: ["memory"], hex: "DDA0DDFF"),
            Swatch(names: ["network"], hex: "FF85C0FF"),
            Swatch(names: ["connectivity"], hex: "FF1493FF"),
            Swatch(names: ["aiModel"], hex: "F48FB1FF"),
            Swatch(names: ["diskHealth"], hex: "F06292FF"),
            Swatch(names: ["processes"], hex: "FF69B4FF")
        ]
    )
    // MARK: - Hello Kitty Pinks Dark
    public static let helloKittyPinksDark = Palette(
        id: "hello-kitty-pinks-dark",
        name: "Hello Kitty Pinks Dark",
        description: "Candy pinks on a deep magenta night.",
        appearance: .dark,
        swatches: [
            Swatch(names: ["Accent"], hex: "FF69B4FF"),
            Swatch(names: ["Background"], hex: "2A0A1AFF"),
            Swatch(names: ["Surface"], hex: "3D0F26FF"),
            Swatch(names: ["Text"], hex: "FFFFFFCC"),
            Swatch(names: ["Subtext"], hex: "F8BBD0FF"),
            Swatch(names: ["blue"], hex: "FF69B4FF"),
            Swatch(names: ["lavender"], hex: "DDA0DDFF"),
            Swatch(names: ["pink"], hex: "FF69B4FF"),
            Swatch(names: ["red"], hex: "F06292FF"),
            Swatch(names: ["peach"], hex: "FFAB91FF"),
            Swatch(names: ["yellow"], hex: "FFD54FFF"),
            Swatch(names: ["green"], hex: "F48FB1FF"),
            Swatch(names: ["teal"], hex: "F48FB1FF"),
            Swatch(names: ["sky"], hex: "FF85C0FF"),
            Swatch(names: ["sapphire"], hex: "FF69B4FF"),
            Swatch(names: ["cpu"], hex: "FF69B4FF"),
            Swatch(names: ["mem"], hex: "DDA0DDFF"),
            Swatch(names: ["diskRead"], hex: "F48FB1FF"),
            Swatch(names: ["diskWrite"], hex: "FFAB91FF"),
            Swatch(names: ["netDown"], hex: "F48FB1FF"),
            Swatch(names: ["netUp"], hex: "FFAB91FF"),
            Swatch(names: ["wifi"], hex: "FF85C0FF"),
            Swatch(names: ["bt"], hex: "FF69B4FF"),
            Swatch(names: ["tb"], hex: "FFD54FFF"),
            Swatch(names: ["usb"], hex: "F48FB1FF"),
            Swatch(names: ["proc"], hex: "FF69B4FF"),
            Swatch(names: ["ai"], hex: "FF85C0FF"),
            Swatch(names: ["cpu"], hex: "FF69B4FF"),
            Swatch(names: ["memory"], hex: "DDA0DDFF"),
            Swatch(names: ["network"], hex: "FF85C0FF"),
            Swatch(names: ["connectivity"], hex: "FF69B4FF"),
            Swatch(names: ["aiModel"], hex: "F48FB1FF"),
            Swatch(names: ["diskHealth"], hex: "F06292FF"),
            Swatch(names: ["processes"], hex: "FF69B4FF")
        ]
    )
    // MARK: - Rainbows and Unicorns Light
    public static let rainbowsAndUnicornsLight = Palette(
        id: "rainbows-and-unicorns-light",
        name: "Rainbows and Unicorns Light",
        description: "Vibrant rainbow panels on a light cloud background.",
        appearance: .light,
        swatches: [
            Swatch(names: ["Accent"], hex: "FF0080FF"),
            Swatch(names: ["Background"], hex: "F8F4FFFF"),
            Swatch(names: ["Surface"], hex: "E6F7FFFF"),
            Swatch(names: ["Text"], hex: "1565C0FF"),
            Swatch(names: ["Subtext"], hex: "1976D2FF"),
            Swatch(names: ["blue"], hex: "0000FFFF"),
            Swatch(names: ["lavender"], hex: "9400D3FF"),
            Swatch(names: ["pink"], hex: "FF0080FF"),
            Swatch(names: ["red"], hex: "FF0000FF"),
            Swatch(names: ["peach"], hex: "FF7F00FF"),
            Swatch(names: ["yellow"], hex: "FFFF00FF"),
            Swatch(names: ["green"], hex: "00FF00FF"),
            Swatch(names: ["teal"], hex: "00FFFFFF"),
            Swatch(names: ["sky"], hex: "00FFFFFF"),
            Swatch(names: ["sapphire"], hex: "0000FFFF"),
            Swatch(names: ["cpu"], hex: "FF0000FF"),
            Swatch(names: ["mem"], hex: "FF7F00FF"),
            Swatch(names: ["diskRead"], hex: "00FF00FF"),
            Swatch(names: ["diskWrite"], hex: "FFFF00FF"),
            Swatch(names: ["netDown"], hex: "00FFFFFF"),
            Swatch(names: ["netUp"], hex: "0000FFFF"),
            Swatch(names: ["wifi"], hex: "9400D3FF"),
            Swatch(names: ["bt"], hex: "FF0080FF"),
            Swatch(names: ["tb"], hex: "FF7F00FF"),
            Swatch(names: ["usb"], hex: "00FF00FF"),
            Swatch(names: ["proc"], hex: "FF0000FF"),
            Swatch(names: ["ai"], hex: "9400D3FF"),
            Swatch(names: ["cpu"], hex: "FF0000FF"),
            Swatch(names: ["memory"], hex: "FF7F00FF"),
            Swatch(names: ["network"], hex: "FFFF00FF"),
            Swatch(names: ["connectivity"], hex: "00FF00FF"),
            Swatch(names: ["aiModel"], hex: "0000FFFF"),
            Swatch(names: ["diskHealth"], hex: "9400D3FF"),
            Swatch(names: ["processes"], hex: "FF0080FF")
        ]
    )
    // MARK: - Rainbows and Unicorns Dark
    public static let rainbowsAndUnicornsDark = Palette(
        id: "rainbows-and-unicorns-dark",
        name: "Rainbows and Unicorns Dark",
        description: "Vibrant rainbow panels on a dark night background.",
        appearance: .dark,
        swatches: [
            Swatch(names: ["Accent"], hex: "FF00A0FF"),
            Swatch(names: ["Background"], hex: "1A0A2AFF"),
            Swatch(names: ["Surface"], hex: "251035FF"),
            Swatch(names: ["Text"], hex: "FFFFFFCC"),
            Swatch(names: ["Subtext"], hex: "D0B0E0FF"),
            Swatch(names: ["blue"], hex: "3333FFFF"),
            Swatch(names: ["lavender"], hex: "CC33FFFF"),
            Swatch(names: ["pink"], hex: "FF00A0FF"),
            Swatch(names: ["red"], hex: "FF3333FF"),
            Swatch(names: ["peach"], hex: "FF9933FF"),
            Swatch(names: ["yellow"], hex: "FFFF33FF"),
            Swatch(names: ["green"], hex: "33FF33FF"),
            Swatch(names: ["teal"], hex: "33FFFFFF"),
            Swatch(names: ["sky"], hex: "33FFFFFF"),
            Swatch(names: ["sapphire"], hex: "3333FFFF"),
            Swatch(names: ["cpu"], hex: "FF3333FF"),
            Swatch(names: ["mem"], hex: "FF9933FF"),
            Swatch(names: ["diskRead"], hex: "33FF33FF"),
            Swatch(names: ["diskWrite"], hex: "FFFF33FF"),
            Swatch(names: ["netDown"], hex: "33FFFFFF"),
            Swatch(names: ["netUp"], hex: "3333FFFF"),
            Swatch(names: ["wifi"], hex: "CC33FFFF"),
            Swatch(names: ["bt"], hex: "FF00A0FF"),
            Swatch(names: ["tb"], hex: "FF9933FF"),
            Swatch(names: ["usb"], hex: "33FF33FF"),
            Swatch(names: ["proc"], hex: "FF3333FF"),
            Swatch(names: ["ai"], hex: "CC33FFFF"),
            Swatch(names: ["cpu"], hex: "FF3333FF"),
            Swatch(names: ["memory"], hex: "FF9933FF"),
            Swatch(names: ["network"], hex: "FFFF33FF"),
            Swatch(names: ["connectivity"], hex: "33FF33FF"),
            Swatch(names: ["aiModel"], hex: "3333FFFF"),
            Swatch(names: ["diskHealth"], hex: "CC33FFFF"),
            Swatch(names: ["processes"], hex: "FF00A0FF")
        ]
    )
    // MARK: - Clean and Minimal Light
    public static let cleanAndMinimalLight = Palette(
        id: "clean-and-minimal-light",
        name: "Clean and Minimal Light",
        description: "Soft grays with a restrained accent.",
        appearance: .light,
        swatches: [
            Swatch(names: ["Accent"], hex: "5A7D9AFF"),
            Swatch(names: ["Background"], hex: "F5F5F7FF"),
            Swatch(names: ["Surface"], hex: "EBEBF0FF"),
            Swatch(names: ["Text"], hex: "1D1D1FFF"),
            Swatch(names: ["Subtext"], hex: "5A5A5EFF"),
            Swatch(names: ["blue"], hex: "5A7D9AFF"),
            Swatch(names: ["lavender"], hex: "8A7D9AFF"),
            Swatch(names: ["pink"], hex: "B85C9AFF"),
            Swatch(names: ["red"], hex: "D65A5AFF"),
            Swatch(names: ["peach"], hex: "D69E5AFF"),
            Swatch(names: ["yellow"], hex: "D6B85AFF"),
            Swatch(names: ["green"], hex: "5AA67DFF"),
            Swatch(names: ["teal"], hex: "5A9E9EFF"),
            Swatch(names: ["sky"], hex: "5A7D9AFF"),
            Swatch(names: ["sapphire"], hex: "5A7DB8FF"),
            Swatch(names: ["cpu"], hex: "5A7D9AFF"),
            Swatch(names: ["mem"], hex: "8A7D9AFF"),
            Swatch(names: ["diskRead"], hex: "5A9E9EFF"),
            Swatch(names: ["diskWrite"], hex: "D69E5AFF"),
            Swatch(names: ["netDown"], hex: "5AA67DFF"),
            Swatch(names: ["netUp"], hex: "D69E5AFF"),
            Swatch(names: ["wifi"], hex: "5A7D9AFF"),
            Swatch(names: ["bt"], hex: "8A7D9AFF"),
            Swatch(names: ["tb"], hex: "D6B85AFF"),
            Swatch(names: ["usb"], hex: "5A9E9EFF"),
            Swatch(names: ["proc"], hex: "B85C9AFF"),
            Swatch(names: ["ai"], hex: "5A7D9AFF")
        ]
    )
    // MARK: - Clean and Minimal Dark
    public static let cleanAndMinimalDark = Palette(
        id: "clean-and-minimal-dark",
        name: "Clean and Minimal Dark",
        description: "Soft grays with a restrained accent, dark mode.",
        appearance: .dark,
        swatches: [
            Swatch(names: ["Accent"], hex: "8BA4B8FF"),
            Swatch(names: ["Background"], hex: "1D1D1FFF"),
            Swatch(names: ["Surface"], hex: "2C2C32FF"),
            Swatch(names: ["Text"], hex: "FFFFFFCC"),
            Swatch(names: ["Subtext"], hex: "A0A0A8FF"),
            Swatch(names: ["blue"], hex: "8BA4B8FF"),
            Swatch(names: ["lavender"], hex: "A08BA4FF"),
            Swatch(names: ["pink"], hex: "B88BA4FF"),
            Swatch(names: ["red"], hex: "D68888FF"),
            Swatch(names: ["peach"], hex: "D6B08BFF"),
            Swatch(names: ["yellow"], hex: "D6C88BFF"),
            Swatch(names: ["green"], hex: "8BB8A4FF"),
            Swatch(names: ["teal"], hex: "8BB8B8FF"),
            Swatch(names: ["sky"], hex: "8BA4B8FF"),
            Swatch(names: ["sapphire"], hex: "8BA4D6FF"),
            Swatch(names: ["cpu"], hex: "8BA4B8FF"),
            Swatch(names: ["mem"], hex: "A08BA4FF"),
            Swatch(names: ["diskRead"], hex: "8BB8B8FF"),
            Swatch(names: ["diskWrite"], hex: "D6B08BFF"),
            Swatch(names: ["netDown"], hex: "8BB8A4FF"),
            Swatch(names: ["netUp"], hex: "D6B08BFF"),
            Swatch(names: ["wifi"], hex: "8BA4B8FF"),
            Swatch(names: ["bt"], hex: "A08BA4FF"),
            Swatch(names: ["tb"], hex: "D6C88BFF"),
            Swatch(names: ["usb"], hex: "8BB8B8FF"),
            Swatch(names: ["proc"], hex: "B88BA4FF"),
            Swatch(names: ["ai"], hex: "8BA4B8FF")
        ]
    )
    // MARK: - Professional Light
    public static let professionalLight = Palette(
        id: "professional-light",
        name: "Professional Light",
        description: "Navy, slate, and crisp white. Boardroom-ready.",
        appearance: .light,
        swatches: [
            Swatch(names: ["Accent"], hex: "1A3C6EFF"),
            Swatch(names: ["Background"], hex: "F7F9FCFF"),
            Swatch(names: ["Surface"], hex: "E1E8F0FF"),
            Swatch(names: ["Text"], hex: "1F2D3DFF"),
            Swatch(names: ["Subtext"], hex: "4A5A6AFF"),
            Swatch(names: ["blue"], hex: "1A3C6EFF"),
            Swatch(names: ["lavender"], hex: "3C1A6EFF"),
            Swatch(names: ["pink"], hex: "6E1A3CFF"),
            Swatch(names: ["red"], hex: "8B1A1AFF"),
            Swatch(names: ["peach"], hex: "8B5A1AFF"),
            Swatch(names: ["yellow"], hex: "8B7B1AFF"),
            Swatch(names: ["green"], hex: "1A6E3CFF"),
            Swatch(names: ["teal"], hex: "1A6E6EFF"),
            Swatch(names: ["sky"], hex: "1A3C6EFF"),
            Swatch(names: ["sapphire"], hex: "1A4A8BFF"),
            Swatch(names: ["cpu"], hex: "1A3C6EFF"),
            Swatch(names: ["mem"], hex: "3C1A6EFF"),
            Swatch(names: ["diskRead"], hex: "1A6E6EFF"),
            Swatch(names: ["diskWrite"], hex: "8B5A1AFF"),
            Swatch(names: ["netDown"], hex: "1A6E3CFF"),
            Swatch(names: ["netUp"], hex: "8B5A1AFF"),
            Swatch(names: ["wifi"], hex: "1A3C6EFF"),
            Swatch(names: ["bt"], hex: "3C1A6EFF"),
            Swatch(names: ["tb"], hex: "8B7B1AFF"),
            Swatch(names: ["usb"], hex: "1A6E6EFF"),
            Swatch(names: ["proc"], hex: "6E1A3CFF"),
            Swatch(names: ["ai"], hex: "1A3C6EFF")
        ]
    )
    // MARK: - Professional Dark
    public static let professionalDark = Palette(
        id: "professional-dark",
        name: "Professional Dark",
        description: "Navy, slate, and crisp white. Boardroom-ready.",
        appearance: .dark,
        swatches: [
            Swatch(names: ["Accent"], hex: "5A8CCBFF"),
            Swatch(names: ["Background"], hex: "0F1720FF"),
            Swatch(names: ["Surface"], hex: "1E2D3DFF"),
            Swatch(names: ["Text"], hex: "FFFFFFCC"),
            Swatch(names: ["Subtext"], hex: "8A9AABFF"),
            Swatch(names: ["blue"], hex: "5A8CCBFF"),
            Swatch(names: ["lavender"], hex: "8A5ACBFF"),
            Swatch(names: ["pink"], hex: "CB5A8CFF"),
            Swatch(names: ["red"], hex: "CB5A5AFF"),
            Swatch(names: ["peach"], hex: "CB8B5AFF"),
            Swatch(names: ["yellow"], hex: "CBAE5AFF"),
            Swatch(names: ["green"], hex: "5ACB8CFF"),
            Swatch(names: ["teal"], hex: "5ACBCBFF"),
            Swatch(names: ["sky"], hex: "5A8CCBFF"),
            Swatch(names: ["sapphire"], hex: "5A8CCBFF"),
            Swatch(names: ["cpu"], hex: "5A8CCBFF"),
            Swatch(names: ["mem"], hex: "8A5ACBFF"),
            Swatch(names: ["diskRead"], hex: "5ACBCBFF"),
            Swatch(names: ["diskWrite"], hex: "CB8B5AFF"),
            Swatch(names: ["netDown"], hex: "5ACB8CFF"),
            Swatch(names: ["netUp"], hex: "CB8B5AFF"),
            Swatch(names: ["wifi"], hex: "5A8CCBFF"),
            Swatch(names: ["bt"], hex: "8A5ACBFF"),
            Swatch(names: ["tb"], hex: "CBAE5AFF"),
            Swatch(names: ["usb"], hex: "5ACBCBFF"),
            Swatch(names: ["proc"], hex: "CB5A8CFF"),
            Swatch(names: ["ai"], hex: "5A8CCBFF")
        ]
    )
    // MARK: - btop Tokyo Night
    public static let btopTokyoNight = Palette(
        id: "btop-tokyo-night",
        name: "btop Tokyo Night",
        description: "Cyan highlights on the deep blue of the Tokyo night skyline.",
        appearance: .dark,
        swatches: [
            Swatch(names: ["Accent"], hex: "7DCFFFFF"),
            Swatch(names: ["Background"], hex: "1A1B26FF"),
            Swatch(names: ["Surface"], hex: "1F2335FF"),
            Swatch(names: ["Text"], hex: "CFC9C2FF"),
            Swatch(names: ["Subtext"], hex: "565F89FF"),
            Swatch(names: ["blue"], hex: "7DCFFFFF"),
            Swatch(names: ["lavender"], hex: "BB9AF7FF"),
            Swatch(names: ["pink"], hex: "F7768EFF"),
            Swatch(names: ["red"], hex: "F7768EFF"),
            Swatch(names: ["peach"], hex: "E0AF68FF"),
            Swatch(names: ["yellow"], hex: "E0AF68FF"),
            Swatch(names: ["green"], hex: "9ECE6AFF"),
            Swatch(names: ["teal"], hex: "2AA198FF"),
            Swatch(names: ["sky"], hex: "7DCFFFFF"),
            Swatch(names: ["sapphire"], hex: "7AA2F7FF"),
            Swatch(names: ["cpu"], hex: "7DCFFFFF"),
            Swatch(names: ["mem"], hex: "BB9AF7FF"),
            Swatch(names: ["diskRead"], hex: "2AA198FF"),
            Swatch(names: ["diskWrite"], hex: "E0AF68FF"),
            Swatch(names: ["netDown"], hex: "9ECE6AFF"),
            Swatch(names: ["netUp"], hex: "E0AF68FF"),
            Swatch(names: ["wifi"], hex: "7DCFFFFF"),
            Swatch(names: ["bt"], hex: "BB9AF7FF"),
            Swatch(names: ["tb"], hex: "E0AF68FF"),
            Swatch(names: ["usb"], hex: "2AA198FF"),
            Swatch(names: ["proc"], hex: "F7768EFF"),
            Swatch(names: ["ai"], hex: "BB9AF7FF"),
            Swatch(names: ["cpu"], hex: "7DCFFFFF"),
            Swatch(names: ["memory"], hex: "BB9AF7FF"),
            Swatch(names: ["network"], hex: "E0AF68FF"),
            Swatch(names: ["connectivity"], hex: "F7768EFF"),
            Swatch(names: ["aiModel"], hex: "7DCFFFFF"),
            Swatch(names: ["diskHealth"], hex: "9ECE6AFF"),
            Swatch(names: ["processes"], hex: "7DCFFFFF")
        ]
    )
    // MARK: - btop Nord Dark
    public static let btopNordDark = Palette(
        id: "btop-nord-dark",
        name: "btop Nord Dark",
        description: "Arctic blues and frost accents from the north.",
        appearance: .dark,
        swatches: [
            Swatch(names: ["Accent"], hex: "88C0D0FF"),
            Swatch(names: ["Background"], hex: "2E3440FF"),
            Swatch(names: ["Surface"], hex: "3B4252FF"),
            Swatch(names: ["Text"], hex: "D8DEE9FF"),
            Swatch(names: ["Subtext"], hex: "4C566AFF"),
            Swatch(names: ["blue"], hex: "88C0D0FF"),
            Swatch(names: ["lavender"], hex: "B48EADFF"),
            Swatch(names: ["pink"], hex: "BF616AFF"),
            Swatch(names: ["red"], hex: "BF616AFF"),
            Swatch(names: ["peach"], hex: "EBCB8BFF"),
            Swatch(names: ["yellow"], hex: "EBCB8BFF"),
            Swatch(names: ["green"], hex: "A3BE8CFF"),
            Swatch(names: ["teal"], hex: "8FBCBBFF"),
            Swatch(names: ["sky"], hex: "88C0D0FF"),
            Swatch(names: ["sapphire"], hex: "5E81ACFF"),
            Swatch(names: ["cpu"], hex: "88C0D0FF"),
            Swatch(names: ["mem"], hex: "B48EADFF"),
            Swatch(names: ["diskRead"], hex: "8FBCBBFF"),
            Swatch(names: ["diskWrite"], hex: "EBCB8BFF"),
            Swatch(names: ["netDown"], hex: "A3BE8CFF"),
            Swatch(names: ["netUp"], hex: "EBCB8BFF"),
            Swatch(names: ["wifi"], hex: "88C0D0FF"),
            Swatch(names: ["bt"], hex: "B48EADFF"),
            Swatch(names: ["tb"], hex: "EBCB8BFF"),
            Swatch(names: ["usb"], hex: "8FBCBBFF"),
            Swatch(names: ["proc"], hex: "BF616AFF"),
            Swatch(names: ["ai"], hex: "B48EADFF"),
            Swatch(names: ["cpu"], hex: "88C0D0FF"),
            Swatch(names: ["memory"], hex: "B48EADFF"),
            Swatch(names: ["network"], hex: "EBCB8BFF"),
            Swatch(names: ["connectivity"], hex: "BF616AFF"),
            Swatch(names: ["aiModel"], hex: "88C0D0FF"),
            Swatch(names: ["diskHealth"], hex: "A3BE8CFF"),
            Swatch(names: ["processes"], hex: "88C0D0FF")
        ]
    )
    // MARK: - btop Nord Light
    public static let btopNordLight = Palette(
        id: "btop-nord-light",
        name: "btop Nord Light",
        description: "Polar white fields with frost accents.",
        appearance: .light,
        swatches: [
            Swatch(names: ["Accent"], hex: "5E81ACFF"),
            Swatch(names: ["Background"], hex: "ECEFF4FF"),
            Swatch(names: ["Surface"], hex: "D8DEE9FF"),
            Swatch(names: ["Text"], hex: "2E3440FF"),
            Swatch(names: ["Subtext"], hex: "4C566AFF"),
            Swatch(names: ["blue"], hex: "5E81ACFF"),
            Swatch(names: ["lavender"], hex: "B48EADFF"),
            Swatch(names: ["pink"], hex: "BF616AFF"),
            Swatch(names: ["red"], hex: "BF616AFF"),
            Swatch(names: ["peach"], hex: "D08770FF"),
            Swatch(names: ["yellow"], hex: "D08770FF"),
            Swatch(names: ["green"], hex: "A3BE8CFF"),
            Swatch(names: ["teal"], hex: "8FBCBBFF"),
            Swatch(names: ["sky"], hex: "5E81ACFF"),
            Swatch(names: ["sapphire"], hex: "5E81ACFF"),
            Swatch(names: ["cpu"], hex: "5E81ACFF"),
            Swatch(names: ["mem"], hex: "B48EADFF"),
            Swatch(names: ["diskRead"], hex: "8FBCBBFF"),
            Swatch(names: ["diskWrite"], hex: "D08770FF"),
            Swatch(names: ["netDown"], hex: "A3BE8CFF"),
            Swatch(names: ["netUp"], hex: "D08770FF"),
            Swatch(names: ["wifi"], hex: "5E81ACFF"),
            Swatch(names: ["bt"], hex: "B48EADFF"),
            Swatch(names: ["tb"], hex: "D08770FF"),
            Swatch(names: ["usb"], hex: "8FBCBBFF"),
            Swatch(names: ["proc"], hex: "BF616AFF"),
            Swatch(names: ["ai"], hex: "B48EADFF"),
            Swatch(names: ["cpu"], hex: "5E81ACFF"),
            Swatch(names: ["memory"], hex: "B48EADFF"),
            Swatch(names: ["network"], hex: "D08770FF"),
            Swatch(names: ["connectivity"], hex: "BF616AFF"),
            Swatch(names: ["aiModel"], hex: "5E81ACFF"),
            Swatch(names: ["diskHealth"], hex: "A3BE8CFF"),
            Swatch(names: ["processes"], hex: "5E81ACFF")
        ]
    )
    // MARK: - btop Solarized Dark
    public static let btopSolarizedDark = Palette(
        id: "btop-solarized-dark",
        name: "btop Solarized Dark",
        description: "Ethan Schoonover's precision colors on a deep teal field.",
        appearance: .dark,
        swatches: [
            Swatch(names: ["Accent"], hex: "B58900FF"),
            Swatch(names: ["Background"], hex: "002B36FF"),
            Swatch(names: ["Surface"], hex: "073642FF"),
            Swatch(names: ["Text"], hex: "EEE8D5FF"),
            Swatch(names: ["Subtext"], hex: "586E75FF"),
            Swatch(names: ["blue"], hex: "268BD2FF"),
            Swatch(names: ["lavender"], hex: "6C71C4FF"),
            Swatch(names: ["pink"], hex: "D33682FF"),
            Swatch(names: ["red"], hex: "DC322FFF"),
            Swatch(names: ["peach"], hex: "CB4B16FF"),
            Swatch(names: ["yellow"], hex: "B58900FF"),
            Swatch(names: ["green"], hex: "859900FF"),
            Swatch(names: ["teal"], hex: "2AA198FF"),
            Swatch(names: ["sky"], hex: "268BD2FF"),
            Swatch(names: ["sapphire"], hex: "268BD2FF"),
            Swatch(names: ["cpu"], hex: "268BD2FF"),
            Swatch(names: ["mem"], hex: "6C71C4FF"),
            Swatch(names: ["diskRead"], hex: "2AA198FF"),
            Swatch(names: ["diskWrite"], hex: "CB4B16FF"),
            Swatch(names: ["netDown"], hex: "859900FF"),
            Swatch(names: ["netUp"], hex: "CB4B16FF"),
            Swatch(names: ["wifi"], hex: "268BD2FF"),
            Swatch(names: ["bt"], hex: "6C71C4FF"),
            Swatch(names: ["tb"], hex: "B58900FF"),
            Swatch(names: ["usb"], hex: "2AA198FF"),
            Swatch(names: ["proc"], hex: "DC322FFF"),
            Swatch(names: ["ai"], hex: "6C71C4FF"),
            Swatch(names: ["cpu"], hex: "268BD2FF"),
            Swatch(names: ["memory"], hex: "6C71C4FF"),
            Swatch(names: ["network"], hex: "B58900FF"),
            Swatch(names: ["connectivity"], hex: "DC322FFF"),
            Swatch(names: ["aiModel"], hex: "268BD2FF"),
            Swatch(names: ["diskHealth"], hex: "859900FF"),
            Swatch(names: ["processes"], hex: "268BD2FF")
        ]
    )
    // MARK: - btop Solarized Light
    public static let btopSolarizedLight = Palette(
        id: "btop-solarized-light",
        name: "btop Solarized Light",
        description: "Warm paper tones with the same precision palette.",
        appearance: .light,
        swatches: [
            Swatch(names: ["Accent"], hex: "B58900FF"),
            Swatch(names: ["Background"], hex: "FDF6E3FF"),
            Swatch(names: ["Surface"], hex: "EEE8D5FF"),
            Swatch(names: ["Text"], hex: "586E75FF"),
            Swatch(names: ["Subtext"], hex: "93A1A1FF"),
            Swatch(names: ["blue"], hex: "268BD2FF"),
            Swatch(names: ["lavender"], hex: "6C71C4FF"),
            Swatch(names: ["pink"], hex: "D33682FF"),
            Swatch(names: ["red"], hex: "DC322FFF"),
            Swatch(names: ["peach"], hex: "CB4B16FF"),
            Swatch(names: ["yellow"], hex: "B58900FF"),
            Swatch(names: ["green"], hex: "859900FF"),
            Swatch(names: ["teal"], hex: "2AA198FF"),
            Swatch(names: ["sky"], hex: "268BD2FF"),
            Swatch(names: ["sapphire"], hex: "268BD2FF"),
            Swatch(names: ["cpu"], hex: "268BD2FF"),
            Swatch(names: ["mem"], hex: "6C71C4FF"),
            Swatch(names: ["diskRead"], hex: "2AA198FF"),
            Swatch(names: ["diskWrite"], hex: "CB4B16FF"),
            Swatch(names: ["netDown"], hex: "859900FF"),
            Swatch(names: ["netUp"], hex: "CB4B16FF"),
            Swatch(names: ["wifi"], hex: "268BD2FF"),
            Swatch(names: ["bt"], hex: "6C71C4FF"),
            Swatch(names: ["tb"], hex: "B58900FF"),
            Swatch(names: ["usb"], hex: "2AA198FF"),
            Swatch(names: ["proc"], hex: "DC322FFF"),
            Swatch(names: ["ai"], hex: "6C71C4FF"),
            Swatch(names: ["cpu"], hex: "268BD2FF"),
            Swatch(names: ["memory"], hex: "6C71C4FF"),
            Swatch(names: ["network"], hex: "B58900FF"),
            Swatch(names: ["connectivity"], hex: "DC322FFF"),
            Swatch(names: ["aiModel"], hex: "268BD2FF"),
            Swatch(names: ["diskHealth"], hex: "859900FF"),
            Swatch(names: ["processes"], hex: "268BD2FF")
        ]
    )
    // MARK: - btop One Dark
    public static let btopOneDark = Palette(
        id: "btop-one-dark",
        name: "btop One Dark",
        description: "Atom's iconic editor palette, blue highlights on charcoal.",
        appearance: .dark,
        swatches: [
            Swatch(names: ["Accent"], hex: "61AFEFFF"),
            Swatch(names: ["Background"], hex: "282C34FF"),
            Swatch(names: ["Surface"], hex: "2C313CFF"),
            Swatch(names: ["Text"], hex: "ABB2BFFF"),
            Swatch(names: ["Subtext"], hex: "5C6370FF"),
            Swatch(names: ["blue"], hex: "61AFEFFF"),
            Swatch(names: ["lavender"], hex: "C678DDFF"),
            Swatch(names: ["pink"], hex: "E06C75FF"),
            Swatch(names: ["red"], hex: "E06C75FF"),
            Swatch(names: ["peach"], hex: "E5C07BFF"),
            Swatch(names: ["yellow"], hex: "E5C07BFF"),
            Swatch(names: ["green"], hex: "98C379FF"),
            Swatch(names: ["teal"], hex: "56B6C2FF"),
            Swatch(names: ["sky"], hex: "61AFEFFF"),
            Swatch(names: ["sapphire"], hex: "61AFEFFF"),
            Swatch(names: ["cpu"], hex: "61AFEFFF"),
            Swatch(names: ["mem"], hex: "C678DDFF"),
            Swatch(names: ["diskRead"], hex: "56B6C2FF"),
            Swatch(names: ["diskWrite"], hex: "E5C07BFF"),
            Swatch(names: ["netDown"], hex: "98C379FF"),
            Swatch(names: ["netUp"], hex: "E5C07BFF"),
            Swatch(names: ["wifi"], hex: "61AFEFFF"),
            Swatch(names: ["bt"], hex: "C678DDFF"),
            Swatch(names: ["tb"], hex: "E5C07BFF"),
            Swatch(names: ["usb"], hex: "56B6C2FF"),
            Swatch(names: ["proc"], hex: "E06C75FF"),
            Swatch(names: ["ai"], hex: "C678DDFF"),
            Swatch(names: ["cpu"], hex: "61AFEFFF"),
            Swatch(names: ["memory"], hex: "C678DDFF"),
            Swatch(names: ["network"], hex: "E5C07BFF"),
            Swatch(names: ["connectivity"], hex: "E06C75FF"),
            Swatch(names: ["aiModel"], hex: "61AFEFFF"),
            Swatch(names: ["diskHealth"], hex: "98C379FF"),
            Swatch(names: ["processes"], hex: "61AFEFFF")
        ]
    )
    // MARK: - btop Monokai
    public static let btopMonokai = Palette(
        id: "btop-monokai",
        name: "btop Monokai",
        description: "Hot pink and lime on near-black, straight from the editor classic.",
        appearance: .dark,
        swatches: [
            Swatch(names: ["Accent"], hex: "F92672FF"),
            Swatch(names: ["Background"], hex: "121310FF"),
            Swatch(names: ["Surface"], hex: "1E1F1CFF"),
            Swatch(names: ["Text"], hex: "F8F8F2FF"),
            Swatch(names: ["Subtext"], hex: "75715EFF"),
            Swatch(names: ["blue"], hex: "66D9EFFF"),
            Swatch(names: ["lavender"], hex: "AE81FFFF"),
            Swatch(names: ["pink"], hex: "F92672FF"),
            Swatch(names: ["red"], hex: "F92672FF"),
            Swatch(names: ["peach"], hex: "FD971FFF"),
            Swatch(names: ["yellow"], hex: "E6DB74FF"),
            Swatch(names: ["green"], hex: "A6E22EFF"),
            Swatch(names: ["teal"], hex: "66D9EFFF"),
            Swatch(names: ["sky"], hex: "66D9EFFF"),
            Swatch(names: ["sapphire"], hex: "66D9EFFF"),
            Swatch(names: ["cpu"], hex: "66D9EFFF"),
            Swatch(names: ["mem"], hex: "AE81FFFF"),
            Swatch(names: ["diskRead"], hex: "66D9EFFF"),
            Swatch(names: ["diskWrite"], hex: "FD971FFF"),
            Swatch(names: ["netDown"], hex: "A6E22EFF"),
            Swatch(names: ["netUp"], hex: "FD971FFF"),
            Swatch(names: ["wifi"], hex: "66D9EFFF"),
            Swatch(names: ["bt"], hex: "AE81FFFF"),
            Swatch(names: ["tb"], hex: "E6DB74FF"),
            Swatch(names: ["usb"], hex: "66D9EFFF"),
            Swatch(names: ["proc"], hex: "F92672FF"),
            Swatch(names: ["ai"], hex: "AE81FFFF"),
            Swatch(names: ["cpu"], hex: "66D9EFFF"),
            Swatch(names: ["memory"], hex: "AE81FFFF"),
            Swatch(names: ["network"], hex: "E6DB74FF"),
            Swatch(names: ["connectivity"], hex: "F92672FF"),
            Swatch(names: ["aiModel"], hex: "66D9EFFF"),
            Swatch(names: ["diskHealth"], hex: "A6E22EFF"),
            Swatch(names: ["processes"], hex: "66D9EFFF")
        ]
    )

    // MARK: - All palettes

    public static let allPalettes: [Palette] = [
        systemDefault,
        matrixDark,
        matrixLight,
        cyberpunkNeonDark,
        cyberpunkNeonLight,
        helloKittyPinksLight,
        helloKittyPinksDark,
        rainbowsAndUnicornsLight,
        rainbowsAndUnicornsDark,
        cleanAndMinimalLight,
        cleanAndMinimalDark,
        professionalLight,
        professionalDark,
        btopTokyoNight,
        btopNordDark,
        btopNordLight,
        btopSolarizedDark,
        btopSolarizedLight,
        btopOneDark,
        btopMonokai
    ]

    /// Every unique color across every built-in palette, deduplicated by hex.
    public static let allSwatches: [Swatch] = {
        var map: [String: [String]] = [:]
        for palette in allPalettes {
            for swatch in palette.swatches {
                map[swatch.hex, default: []].append(contentsOf: swatch.names)
            }
        }
        return map.map { Swatch(names: Array(Set($0.value)).sorted(), hex: $0.key) }
    }()
}
