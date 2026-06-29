import AppKit
import SwiftUI

/// Centralizes the menu's spacing, radius, and padding so the compact surface stays consistent and
/// every value has one place to change — replacing the drifting 6/7/8/10 literals the surfaces used.
enum KkachiMenuMetrics {
    /// One corner radius for every compact surface: rows, cards, the primary action, and the material.
    static let cornerRadius: CGFloat = 8

    /// Padding inside the elevated cards (permission, restore-failure, undo, first-run priming).
    static let cardPadding: CGFloat = 10

    /// Padding inside the flat list rows (at-risk queue, restore history).
    static let rowPadding: CGFloat = 6

    /// Vertical rhythm between the menu's major sections.
    static let sectionSpacing: CGFloat = 10
}

/// Centralizes menu colors so the compact surface keeps a consistent identity.
enum KkachiMenuPalette {
    /// Provides a neutral for paused and non-urgent waiting states; passes >=3:1 in both appearances.
    static let wingGray = Color(red: 0.471, green: 0.490, blue: 0.471)

    /// Provides a calm restoration tone for tabs held locally. Lightened in dark mode so the status
    /// glyph keeps >=3:1 graphical contrast (WCAG 1.4.11) over translucent dark menu material.
    static let returnBlue = dynamicColor(light: (0.231, 0.404, 0.529), dark: (0.40, 0.58, 0.74))

    /// Provides a restrained branch tone for setup attention; passes >=3:1 in both appearances.
    static let warningGold = Color(red: 0.678, green: 0.478, blue: 0.157)

    /// Provides an urgent error tone for automation failures, kept distinct from the setup-warning gold
    /// so a genuine failure reads as more severe than an incomplete-setup nudge. Lightened in dark mode
    /// so the glyph keeps >=3:1 graphical contrast (WCAG 1.4.11) over translucent dark menu material.
    static let criticalRed = dynamicColor(light: (0.72, 0.13, 0.11), dark: (0.95, 0.45, 0.42))

    /// Provides the faint row fill used instead of stacked card decoration.
    static let rowFill = Color.primary.opacity(0.035)

    /// Provides a slightly stronger fill on pointer hover so list rows feel responsive.
    static let rowFillHover = Color.primary.opacity(0.08)

    /// Fills the prominent action button for attention/restore; dark enough for white text >=4.5:1.
    static let attentionFill = Color(red: 0.231, green: 0.404, blue: 0.529)

    /// Fills the prominent action button for setup warnings; darker gold so white text reaches AA.
    static let warningFill = Color(red: 0.58, green: 0.40, blue: 0.12)

    /// Fills the prominent action button for automation errors; a deep red dark enough for white text
    /// to clear AA (>=4.5:1), giving recovery from a real failure more urgency than a setup warning.
    static let criticalFill = Color(red: 0.66, green: 0.18, blue: 0.17)

    /// Fills the prominent action button for steady/idle commands; neutral that keeps white text at AA.
    static let steadyFill = Color(red: 0.38, green: 0.40, blue: 0.38)

    /// Builds an appearance-aware sRGB color so a menu tone can differ between light and dark mode.
    private static func dynamicColor(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let component = isDark ? dark : light
            return NSColor(srgbRed: component.0, green: component.1, blue: component.2, alpha: 1)
        })
    }
}

/// Applies the app's compact menu surface treatment with macOS 26 enhancement.
private struct MenuSurfaceModifier: ViewModifier {
    /// Wraps content in a restrained material appropriate for menu-bar utilities.
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: KkachiMenuMetrics.cornerRadius))
        } else {
            content
                .background(.quaternary.opacity(0.72), in: RoundedRectangle(cornerRadius: KkachiMenuMetrics.cornerRadius))
        }
    }
}

/// Exposes reusable menu surface styling to small dashboard components.
extension View {
    /// Adds a compact rounded surface while keeping sections visually lightweight.
    func menuSurface() -> some View {
        modifier(MenuSurfaceModifier())
    }
}

/// Styles the one command that the status menu wants people to notice first.
struct KkachiPrimaryActionButtonStyle: ButtonStyle {
    /// Stores the semantic accent chosen by the menu action owner.
    let accentColor: Color

    /// Indicates whether this action should use filled emphasis.
    let isProminent: Bool

    /// Applies a stable full-width shape without layout-shifting press feedback.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 38)
            .padding(.horizontal, 10)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor(for: configuration), in: RoundedRectangle(cornerRadius: KkachiMenuMetrics.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: KkachiMenuMetrics.cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.78 : 1)
    }

    /// Chooses text contrast for filled and quiet button states.
    private var foregroundColor: Color {
        isProminent ? .white : .primary
    }

    /// Chooses a subtle border for secondary actions.
    private var borderColor: Color {
        isProminent ? accentColor.opacity(0.0) : Color.primary.opacity(0.16)
    }

    /// Chooses a filled or quiet background without adding shadows.
    private func backgroundColor(for configuration: Configuration) -> Color {
        if isProminent {
            return accentColor.opacity(configuration.isPressed ? 0.84 : 1)
        }
        return Color.primary.opacity(configuration.isPressed ? 0.10 : 0.055)
    }
}

/// Maps domain urgency to the single accent used by the menu rail and actions.
extension MenuTone {
    /// Returns a restrained color that communicates state without a busy palette.
    var menuAccentColor: Color {
        switch self {
        case .steady:
            return KkachiMenuPalette.wingGray
        case .attention:
            return KkachiMenuPalette.returnBlue
        case .warning:
            return KkachiMenuPalette.warningGold
        case .critical:
            return KkachiMenuPalette.criticalRed
        case .idle:
            return KkachiMenuPalette.wingGray
        }
    }

    /// Returns a contrast-safe fill for the one prominent action button in this state, kept separate
    /// from the glyph tone so white button text stays at AA while the glyph stays light enough to read.
    var prominentFillColor: Color {
        switch self {
        case .steady, .idle:
            return KkachiMenuPalette.steadyFill
        case .attention:
            return KkachiMenuPalette.attentionFill
        case .warning:
            return KkachiMenuPalette.warningFill
        case .critical:
            return KkachiMenuPalette.criticalFill
        }
    }
}

/// Collapses an animation to no motion when the user prefers Reduce Motion, so every menu transition
/// honors accessibility from one place. New motion work should funnel through `kkachiAnimation`.
private struct ReduceMotionAnimation<V: Equatable>: ViewModifier {
    /// Stores the animation used when motion is allowed.
    let animation: Animation

    /// Stores the value whose changes drive the animation.
    let value: V

    /// Reads the live Reduce Motion accessibility preference.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Animates `value` changes unless Reduce Motion is on, in which case the change is instant.
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    /// Animates `value` changes, but instantly when Reduce Motion is enabled.
    func kkachiAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(ReduceMotionAnimation(animation: animation, value: value))
    }
}
