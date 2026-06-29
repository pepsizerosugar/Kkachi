import AppKit
import Foundation

/// Supplies the menu-bar status item's template image for a mood. It prefers the dedicated magpie art
/// (`KkachiMascot_{state}_00` imageset shipped by the art pipeline) and falls back to today's procedural
/// branch mark when a state's still is absent — so the menu bar always shows a correct, *static* icon for
/// the current mood. The menu-bar mark never animates: only the mood (which still it shows) changes, so
/// the status item stays energy-quiet and consistent with macOS menu-bar conventions.
@MainActor
final class MascotFrameProvider {
    /// Names the single brand silhouette used as the last-resort still before any mascot art exists.
    private static let baseIconName = "MenuBarIcon"

    /// Defines the menu-bar image canvas in points.
    private let imageSize = NSSize(width: 18, height: 18)

    /// Loads named AppKit images so tests can inject missing-asset and art-present scenarios.
    private let imageLoader: (String) -> NSImage?

    /// Creates a provider using the packaged asset catalog, or an injected loader for tests.
    init(imageLoader: @escaping (String) -> NSImage? = { NSImage(named: $0) }) {
        self.imageLoader = imageLoader
    }

    /// Returns the static template image for a mood: the delivered mascot still (`00`) when present,
    /// otherwise the procedural branch mark, otherwise an SF Symbol — so this never returns nothing and
    /// the menu bar is never blank.
    func image(for mood: KkachiMood, fallbackSymbolName: String) -> NSImage {
        if let still = mascotStill(for: mood) {
            return still
        }
        guard let baseImage = imageLoader(Self.baseIconName)?.copy() as? NSImage else {
            return fallbackImage(symbolName: fallbackSymbolName)
        }
        return branchStatusImage(for: mood, baseImage: baseImage)
    }

    /// Loads a mood's delivered still (`KkachiMascot_{state}_00`) as a template image sized to the
    /// menu-bar canvas, or nil when that art has not been shipped yet.
    private func mascotStill(for mood: KkachiMood) -> NSImage? {
        guard let frame = imageLoader("KkachiMascot_\(mood.rawValue)_00")?.copy() as? NSImage else {
            return nil
        }
        frame.size = imageSize
        frame.isTemplate = true
        return frame
    }

    /// Draws Kkachi as observer while small branch marks carry state.
    private func branchStatusImage(for mood: KkachiMood, baseImage: NSImage) -> NSImage {
        let image = NSImage(size: imageSize)
        image.lockFocus()
        NSColor.black.setStroke()
        NSColor.black.setFill()
        baseImage.draw(in: NSRect(x: 1.2, y: 3.6, width: 12.8, height: 12.8), from: .zero, operation: .sourceOver, fraction: 1)
        drawPerch(isBroken: mood == .blocked)
        drawStatusPieces(for: mood)
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    /// Draws the baseline perch, using a small break for permission recovery.
    private func drawPerch(isBroken: Bool) {
        if isBroken {
            drawLine(from: NSPoint(x: 2.5, y: 4.4), to: NSPoint(x: 7.4, y: 4.4), width: 1.25)
            drawLine(from: NSPoint(x: 10.3, y: 4.0), to: NSPoint(x: 15.5, y: 4.7), width: 1.25)
        } else {
            drawLine(from: NSPoint(x: 2.5, y: 4.4), to: NSPoint(x: 15.5, y: 4.4), width: 1.25)
        }
    }

    /// Adds small static state pieces around the perch instead of changing Kkachi's expression.
    private func drawStatusPieces(for mood: KkachiMood) {
        switch mood {
        case .alert:
            drawSavedPiece(at: NSPoint(x: 13.4, y: 8.6))
            drawSavedPiece(at: NSPoint(x: 15.2, y: 6.8))
        case .pruning:
            drawSavedPiece(at: NSPoint(x: 14.4, y: 5.7))
        case .paused:
            drawLine(from: NSPoint(x: 12.2, y: 2.8), to: NSPoint(x: 14.3, y: 6.4), width: 1.05)
            drawLine(from: NSPoint(x: 14.3, y: 2.8), to: NSPoint(x: 12.2, y: 6.4), width: 1.05)
        case .restoreAvailable:
            drawLine(from: NSPoint(x: 13.8, y: 3.1), to: NSPoint(x: 13.8, y: 1.7), width: 1.05)
            drawSavedPiece(at: NSPoint(x: 13.8, y: 1.1))
        case .calm, .watching, .blocked:
            break
        }
    }

    /// Draws one retained-tab piece as a small branch-side dot.
    private func drawSavedPiece(at center: NSPoint) {
        let rect = NSRect(x: center.x - 0.75, y: center.y - 0.75, width: 1.5, height: 1.5)
        NSBezierPath(ovalIn: rect).fill()
    }

    /// Draws a round-capped stroke for perch and tie marks.
    private func drawLine(from start: NSPoint, to end: NSPoint, width: CGFloat) {
        let path = NSBezierPath()
        path.lineWidth = width
        path.lineCapStyle = .round
        path.move(to: start)
        path.line(to: end)
        path.stroke()
    }

    /// Returns a fallback template symbol if the brand silhouette is unavailable.
    private func fallbackImage(symbolName: String) -> NSImage {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)
            ?? NSImage(size: imageSize)
        image.isTemplate = true
        return image
    }
}
