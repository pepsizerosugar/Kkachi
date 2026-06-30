import Foundation
import UserNotifications

/// Posts the optional "Closed N tabs" notification after a prune cycle. A protocol so the tracker stays
/// testable: unit and UI test runs inject nothing and therefore never touch UNUserNotificationCenter,
/// which is unavailable (and can crash) outside a real, signed app bundle.
@MainActor
protocol PruneNotifying: AnyObject {
    /// Posts one coalesced notification for a just-closed batch, carrying a reopen-all action.
    func notifyPruned(_ batch: PruneBatch)
}

/// UNUserNotificationCenter-backed prune notifier. Requests authorization once on creation, posts one
/// passive notification per close cycle ("Kkachi closed N tabs"), and routes its "Reopen all" action
/// back through `onReopen` (passing the batch id) so tapping it restores that specific batch without
/// opening the menu. Owned strongly by the tracker because the notification center keeps only a weak
/// delegate.
@MainActor
final class PruneNotifier: NSObject, PruneNotifying {
    /// Identifies the reopen-all action button shown on the notification.
    private static let reopenActionID = "kkachi.prune.reopenAll"

    /// Names the notification category that carries the reopen-all action.
    private static let categoryID = "kkachi.prune.closed"

    /// Reopens the batch named by a notification's identifier (its batch-id string) when the user taps
    /// the banner or its action — so an old banner always reopens the batch it described, never whatever
    /// was closed most recently.
    private let onReopen: (String) -> Void

    /// The system notification center, injectable so the type stays unit-test friendly.
    private let center: UNUserNotificationCenter

    /// Supplies the current app-language preference at the moment a notification is posted.
    private let languageProvider: () -> AppLanguage

    /// Wires the reopen handler, registers the action category, and requests authorization once.
    init(
        center: UNUserNotificationCenter = .current(),
        languageProvider: @escaping () -> AppLanguage = { .system },
        onReopen: @escaping (String) -> Void
    ) {
        self.center = center
        self.languageProvider = languageProvider
        self.onReopen = onReopen
        super.init()
        configure()
    }

    /// Registers the reopen-all category, becomes the delegate, and asks for alert permission a single
    /// time — repeat calls return the existing decision silently, so this is safe on every launch.
    private func configure() {
        registerCategory()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Registers the notification action copy using the current app language.
    private func registerCategory() {
        let reopen = UNNotificationAction(
            identifier: Self.reopenActionID,
            title: AppLocalization.string("notification.pruned.reopenAll", language: languageProvider()),
            options: [.foreground]
        )
        let category = UNNotificationCategory(identifier: Self.categoryID, actions: [reopen], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    /// Posts one passive notification summarizing the batch. The request id is the batch id so a single
    /// cycle can never enqueue duplicate banners, and `.passive` keeps the cleanup quiet, not alarming.
    func notifyPruned(_ batch: PruneBatch) {
        registerCategory()
        let language = languageProvider()
        let content = UNMutableNotificationContent()
        content.title = AppLocalization.string("notification.pruned.title", language: language)
        content.body = Self.body(for: batch.count, language: language)
        content.categoryIdentifier = Self.categoryID
        content.interruptionLevel = .passive
        let request = UNNotificationRequest(identifier: batch.id.uuidString, content: content, trigger: nil)
        center.add(request)
    }

    /// Builds count-correct body copy, choosing singular vs plural so "Closed 1 idle tab" never reads
    /// as "1 tabs". Format strings live in the catalog and substitute the count positionally.
    private static func body(for count: Int, language: AppLanguage) -> String {
        let key = count == 1 ? "notification.pruned.body.one" : "notification.pruned.body.other"
        return AppLocalization.format(key, language: language, count)
    }
}

/// Delivers notifications even while Kkachi is frontmost and routes taps back to the reopen handler on
/// the main actor, so the system "Reopen all" button is wired to the same batch undo the menu uses.
extension PruneNotifier: UNUserNotificationCenterDelegate {
    /// Restores the batch this notification describes when the user taps its body or reopen-all action.
    /// The action identifier and the notification's own identifier (the batch-id string) are captured as
    /// plain strings and used on the main actor, so the isolated category constant is never read here and
    /// the reopen targets the correct batch.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        let batchID = response.notification.request.identifier
        Task { @MainActor in
            let shouldReopen = action == Self.reopenActionID || action == UNNotificationDefaultActionIdentifier
            if shouldReopen { self.onReopen(batchID) }
            completionHandler()
        }
    }

    /// Shows the banner even when the app is active so a close is acknowledged in the moment.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}
