import SwiftUI

/// A subtle press style for the full-width restore and undo rows so the tap itself feels tactile —
/// not just the row animating away afterward. Honors Reduce Motion by dropping the scale.
struct KkachiRowButtonStyle: ButtonStyle {
    /// Wraps the label so the press feedback can read the live Reduce Motion preference.
    func makeBody(configuration: Configuration) -> some View {
        PressableRow(configuration: configuration)
    }

    /// Applies a brief press scale and opacity dip, collapsing to opacity-only under Reduce Motion.
    private struct PressableRow: View {
        let configuration: ButtonStyleConfiguration

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
                .opacity(configuration.isPressed ? 0.9 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}
