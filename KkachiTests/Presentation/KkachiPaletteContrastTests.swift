import AppKit
import SwiftUI
import XCTest
@testable import Kkachi

/// Verifies menu tones meet WCAG contrast so status stays legible in light and dark appearances.
/// These are sign-off invariants for the accessibility floor: a future palette tweak that regresses
/// contrast (the original P0 was the dark-mode glyph at ~2.4:1) fails the build instead of shipping.
@MainActor
final class KkachiPaletteContrastTests: XCTestCase {
    /// Approximates the light menu material background behind the status glyph.
    private let lightBackground = (r: 0.96, g: 0.96, b: 0.96)

    /// Approximates the dark menu material background behind the status glyph.
    private let darkBackground = (r: 0.16, g: 0.16, b: 0.16)

    /// Represents the white button text drawn over a prominent fill.
    private let white = (r: 1.0, g: 1.0, b: 1.0)

    /// Ensures every status glyph tone keeps >=3:1 graphical contrast (WCAG 1.4.11) in both appearances.
    func testGlyphTonesMeetGraphicalContrast() {
        let glyphTones: [(String, Color)] = [
            ("returnBlue", KkachiMenuPalette.returnBlue),
            ("warningGold", KkachiMenuPalette.warningGold),
            ("criticalRed", KkachiMenuPalette.criticalRed),
            ("wingGray", KkachiMenuPalette.wingGray),
        ]
        for (name, tone) in glyphTones {
            XCTAssertGreaterThanOrEqual(contrast(components(of: tone, in: .aqua), lightBackground), 3.0, "\(name) on light material")
            XCTAssertGreaterThanOrEqual(contrast(components(of: tone, in: .darkAqua), darkBackground), 3.0, "\(name) on dark material")
        }
    }

    /// Ensures white button text on every prominent fill clears AA (>=4.5:1) in both appearances.
    func testProminentFillsCarryWhiteTextAtAA() {
        let fills: [(String, Color)] = [
            ("attentionFill", KkachiMenuPalette.attentionFill),
            ("warningFill", KkachiMenuPalette.warningFill),
            ("criticalFill", KkachiMenuPalette.criticalFill),
            ("steadyFill", KkachiMenuPalette.steadyFill),
        ]
        for (name, fill) in fills {
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                XCTAssertGreaterThanOrEqual(contrast(white, components(of: fill, in: appearance)), 4.5, "white on \(name) (\(appearance.rawValue))")
            }
        }
    }

    /// Resolves a SwiftUI color to sRGB components in a specific appearance.
    private func components(of color: Color, in appearanceName: NSAppearance.Name) -> (r: Double, g: Double, b: Double) {
        let nsColor = NSColor(color)
        var resolved = nsColor
        NSAppearance(named: appearanceName)?.performAsCurrentDrawingAppearance {
            resolved = nsColor.usingColorSpace(.sRGB) ?? nsColor
        }
        return (Double(resolved.redComponent), Double(resolved.greenComponent), Double(resolved.blueComponent))
    }

    /// Computes the WCAG contrast ratio between two sRGB colors.
    private func contrast(_ first: (r: Double, g: Double, b: Double), _ second: (r: Double, g: Double, b: Double)) -> Double {
        let lighter = max(relativeLuminance(first), relativeLuminance(second))
        let darker = min(relativeLuminance(first), relativeLuminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Computes WCAG relative luminance from sRGB components.
    private func relativeLuminance(_ color: (r: Double, g: Double, b: Double)) -> Double {
        func linear(_ value: Double) -> Double { value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
    }
}
