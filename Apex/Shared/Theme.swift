import SwiftUI

// MARK: - Theme
/// Central color palette for Apex Flow.
///
/// The static properties now delegate to `ThemeStore.shared` so that user
/// overrides (accent, background, surface, text) are respected everywhere
/// without editing every view.
enum Theme {
    // MARK: - Backgrounds
    @MainActor static var base:     Color { ThemeStore.shared.base }
    @MainActor static var mantle:   Color { Color(hex: "181825") }
    @MainActor static var crust:    Color { Color(hex: "11111b") }
    @MainActor static var surface0: Color { ThemeStore.shared.surface0 }
    @MainActor static var surface1: Color { ThemeStore.shared.surface1 }
    @MainActor static var surface2: Color { ThemeStore.shared.surface2 }

    // MARK: - Text
    @MainActor static var text:     Color { ThemeStore.shared.text }
    @MainActor static var subtext1: Color { ThemeStore.shared.subtext1 }
    @MainActor static var subtext0: Color { ThemeStore.shared.subtext0 }
    @MainActor static var overlay2: Color { ThemeStore.shared.subtext0 }
    @MainActor static var overlay1: Color { ThemeStore.shared.subtext0.opacity(0.85) }
    @MainActor static var overlay0: Color { ThemeStore.shared.overlay0 }

    // MARK: - Accents
    @MainActor static var blue:     Color { ThemeStore.shared.blue }
    @MainActor static var lavender: Color { ThemeStore.shared.lavender }
    @MainActor static var mauve:    Color { ThemeStore.shared.mauve }
    @MainActor static var pink:     Color { ThemeStore.shared.pink }
    @MainActor static var red:      Color { ThemeStore.shared.red }
    @MainActor static var maroon:   Color { ThemeStore.shared.maroon }
    @MainActor static var peach:    Color { ThemeStore.shared.peach }
    @MainActor static var yellow:   Color { ThemeStore.shared.yellow }
    @MainActor static var green:    Color { ThemeStore.shared.green }
    @MainActor static var teal:     Color { ThemeStore.shared.teal }
    @MainActor static var sky:      Color { ThemeStore.shared.sky }
    @MainActor static var sapphire: Color { ThemeStore.shared.sapphire }

    // MARK: - Semantic
    @MainActor static var cpuColor:  Color { ThemeStore.shared.semanticColor(\.cpu, default: blue) }
    @MainActor static var memColor:  Color { ThemeStore.shared.semanticColor(\.mem, default: mauve) }
    @MainActor static var diskRead:  Color { ThemeStore.shared.semanticColor(\.diskRead, default: teal) }
    @MainActor static var diskWrite: Color { ThemeStore.shared.semanticColor(\.diskWrite, default: peach) }
    @MainActor static var netDown:   Color { ThemeStore.shared.semanticColor(\.netDown, default: green) }
    @MainActor static var netUp:     Color { ThemeStore.shared.semanticColor(\.netUp, default: peach) }
    @MainActor static var wifiColor: Color { ThemeStore.shared.semanticColor(\.wifi, default: sky) }
    @MainActor static var btColor:   Color { ThemeStore.shared.semanticColor(\.bt, default: blue) }
    @MainActor static var tbColor:   Color { ThemeStore.shared.semanticColor(\.tb, default: yellow) }
    @MainActor static var usbColor:  Color { ThemeStore.shared.semanticColor(\.usb, default: teal) }
    @MainActor static var procColor: Color { ThemeStore.shared.semanticColor(\.proc, default: lavender) }
    @MainActor static var aiColor:   Color { ThemeStore.shared.semanticColor(\.ai, default: sky) }

    // MARK: - Load gradient  (green → yellow → red)
    @MainActor static func loadColor(_ value: Double) -> Color {
        ThemeStore.shared.loadColor(value)
    }

    // MARK: - Panel style
    static let panelCornerRadius: CGFloat = 10
    static let panelPadding: CGFloat = 10
    static let panelBorderWidth: CGFloat = 1
}

// MARK: - Contrast helpers

extension Color {
    /// Perceived luminance in the range 0...1 using sRGB coefficients.
    /// Values > ~0.5 are generally readable with black text; lower values read
    /// better with white text.
    @MainActor
    var perceivedLuminance: Double {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return 0.5 }
        let r = c.redComponent
        let g = c.greenComponent
        let b = c.blueComponent
        // Rec. 601 luma coefficients give a good perceptual result for UI text.
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    /// Returns black or white, whichever provides better contrast against this
    /// color. Useful for text overlaid on colored badges, bars, or buttons.
    @MainActor
    func readableOverlayColor() -> Color {
        perceivedLuminance > 0.5 ? .black : .white
    }
}

// MARK: - Panel container
struct PanelView<Content: View>: View {
    let title: String
    let accentColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 3, height: 14)
                    .cornerRadius(1.5)
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accentColor)
                Spacer()
            }
            content()
        }
        .padding(Theme.panelPadding)
        .background(Theme.surface0.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.panelCornerRadius)
                .stroke(Theme.surface1, lineWidth: Theme.panelBorderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.panelCornerRadius))
    }
}
