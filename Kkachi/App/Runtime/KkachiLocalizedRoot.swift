import SwiftUI

/// Applies Kkachi's app-language preference to a SwiftUI subtree.
struct KkachiLocalizedRoot<Content: View>: View {
    /// Observes store changes so language updates redraw existing menu and Settings surfaces.
    @ObservedObject var store: KkachiStore

    /// The content that should inherit the selected locale.
    let content: Content

    /// Captures the subtree with normal SwiftUI builder semantics.
    init(store: KkachiStore, @ViewBuilder content: () -> Content) {
        self.store = store
        self.content = content()
    }

    /// Injects either the selected manual locale or the live system locale.
    var body: some View {
        content.environment(\.locale, locale)
    }

    /// Converts the app preference into SwiftUI's locale value.
    private var locale: Locale {
        store.preferences.appLanguage.formattingLocale
    }
}
