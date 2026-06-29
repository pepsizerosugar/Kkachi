import SwiftUI

/// Hosts the menu dashboard while keeping the app entry point stable.
struct MenuView: View {
    /// Observes the app-wide store owned by the app delegate.
    @ObservedObject var store: KkachiStore

    /// Delegates all visible menu content to the dashboard component.
    var body: some View {
        MenuDashboardView(store: store)
    }
}
