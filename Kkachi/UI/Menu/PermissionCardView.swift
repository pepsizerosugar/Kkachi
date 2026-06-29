import SwiftUI

/// Guides setup and permission recovery without duplicating routine status.
struct PermissionCardView: View {
    /// Reads store state so recovery copy matches the current blocker.
    @ObservedObject var store: KkachiStore

    /// Shows context-only recovery guidance because the dashboard owns the one primary command.
    var body: some View {
        if presentation.shouldShowRecoveryCard, let action = presentation.primaryAction {
            VStack(alignment: .leading, spacing: 8) {
                recoveryMessage(for: action)
                if store.visiblePermissionState == .automationDenied {
                    Button("permission.automationDenied.openSettings") {
                        store.openAutomationSettings()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption.weight(.semibold))
                    .accessibilityIdentifier("menu.context.permission.openAutomation")
                }
            }
            .padding(KkachiMenuMetrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KkachiMenuPalette.rowFill, in: RoundedRectangle(cornerRadius: KkachiMenuMetrics.cornerRadius))
            .accessibilityIdentifier("menu.context.permission")
        }
    }

    /// Renders the compact problem explanation for the current recovery state.
    private func recoveryMessage(for action: MenuPrimaryAction) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: action.symbolName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(toneColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(titleKey))
                    .font(.callout.weight(.semibold))
                Text(LocalizedStringKey(messageKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Provides the current menu-level presentation summary.
    private var presentation: MenuPresentationState {
        store.menuPresentationState
    }

    /// Provides a localized title for the current setup state.
    private var titleKey: String {
        switch store.visiblePermissionState {
        case .unknown:
            return "permission.unknown.title"
        case .notInstalled:
            return "permission.notInstalled.title"
        case .disabled:
            return "permission.disabled.title"
        case .browserMissing:
            return "permission.browserMissing.title"
        case .automationDenied:
            return "permission.automationDenied.title"
        case .ready:
            return "permission.ready.title"
        }
    }

    /// Provides concise recovery guidance for the current setup state.
    private var messageKey: String {
        switch store.visiblePermissionState {
        case .unknown:
            return "permission.unknown.message"
        case .notInstalled:
            return "permission.notInstalled.message"
        case .disabled:
            return "permission.disabled.message"
        case .browserMissing:
            return "permission.browserMissing.message"
        case .automationDenied:
            return "permission.automationDenied.message"
        case .ready:
            return "permission.ready.message"
        }
    }

    /// Chooses semantic color that matches the current recovery severity.
    private var toneColor: Color {
        presentation.tone.menuAccentColor
    }
}
