import SwiftUI

/// Renders installed browser participation controls for Settings.
struct SettingsBrowserSectionView: View {
    /// Observes the shared store so browser status and policy stay synchronized.
    @ObservedObject var store: KkachiStore

    /// Keeps unavailable browsers out of the main Settings workflow.
    private var installedBrowserStatuses: [BrowserStatus] {
        store.browserStatuses.filter(\.isInstalled)
    }

    /// Renders a compact installed-only browser list with a directional empty state.
    var body: some View {
        Section("settings.browsers.section") {
            if installedBrowserStatuses.isEmpty {
                Text("settings.browsers.emptyInstalled")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.browsers.emptyInstalled")
            } else {
                ForEach(installedBrowserStatuses) { status in
                    Toggle(isOn: browserBinding(for: status)) {
                        HStack {
                            Text(LocalizedStringKey(status.descriptor.displayNameKey))
                            Spacer()
                            Text(stateKey(for: status))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("settings.browser.\(status.descriptor.id.rawValue)")
                }
            }
        }
    }

    /// Binds an installed browser toggle to persisted pruning policy.
    private func browserBinding(for status: BrowserStatus) -> Binding<Bool> {
        Binding(
            get: { store.preferences.policy.isBrowserEnabled(status.descriptor.id) },
            set: { store.setBrowser(status.descriptor.id, enabled: $0) }
        )
    }

    /// Returns localized browser state text for Settings rows.
    private func stateKey(for status: BrowserStatus) -> LocalizedStringKey {
        switch status.permissionState {
        case .ready:
            return "browser.state.ready"
        case .notInstalled:
            return "browser.state.notInstalled"
        case .disabled:
            return "browser.state.disabled"
        case .browserMissing:
            return "browser.state.notRunning"
        case .automationDenied:
            return "browser.state.automationDenied"
        case .unknown:
            return "browser.state.unknown"
        }
    }
}
