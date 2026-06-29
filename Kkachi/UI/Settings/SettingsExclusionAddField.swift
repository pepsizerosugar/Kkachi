import SwiftUI

/// The Protected Sites add control: a domain field that commits on Return or the Add button, plus a
/// single caption line that forgives mistakes. One typed token is classified so the caption says exactly
/// why it failed (invalid vs already protected) and the text is kept so it can be fixed in place; several
/// comma/whitespace-separated tokens are added in one batch and summarized. Extracted from the section
/// view so the add/feedback logic stays well under the file-length limit.
struct SettingsExclusionAddField: View {
    /// Shared store the add actions mutate; the field reads its exclusions to detect duplicates.
    @ObservedObject var store: KkachiStore

    /// Pending text; kept after a failed single add so the user can correct it without retyping.
    @State private var newExclusion = ""

    /// Classifies the last attempt so the caption can explain the outcome without alarming copy.
    @State private var feedback: AddFeedback = .none

    /// Lays out the input row and the always-present caption beneath it.
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TextField("settings.exclusions.placeholder", text: $newExclusion)
                    .onSubmit(commitAdd)
                    .onChange(of: newExclusion) { _ in feedback = .none }
                    .accessibilityIdentifier("settings.exclusions.input")
                Button("settings.exclusions.add", action: commitAdd)
                    .disabled(newExclusion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("settings.exclusions.add")
            }
            caption
        }
    }

    /// One caption slot, in priority order: a result of the last attempt, then a live preview of the
    /// normalized host Return would protect, then the static paste-many hint when the field is empty.
    @ViewBuilder private var caption: some View {
        switch feedback {
        case .invalid(let token):
            captionText(format("settings.exclusions.feedback.invalid", token), .red)
        case .duplicate(let host):
            captionText(format("settings.exclusions.feedback.duplicate", host), .secondary)
        case .summary(let added, let skipped):
            captionText(summaryText(added: added, skipped: skipped), .secondary)
        case .none:
            if let host = previewHost {
                captionText(format("settings.exclusions.hint.add", host), .secondary)
            } else {
                captionText(NSLocalizedString("settings.exclusions.hint", comment: ""), .secondary)
            }
        }
    }

    /// Renders one caption line with consistent type treatment and a stable test identifier.
    private func captionText(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("settings.exclusions.feedback")
    }

    /// The normalized host a single valid token would protect, or nil when the field is empty, holds
    /// several tokens, or is not a valid domain — so the preview shows exactly what will be stored.
    private var previewHost: String? {
        let tokens = Self.tokens(from: newExclusion)
        guard tokens.count == 1, let rule = DomainExclusionRule(tokens[0]) else { return nil }
        return rule.hostSuffix
    }

    /// Commits the field: a single token is classified for precise feedback; several tokens are added in
    /// one batch (one policy re-evaluation) and summarized.
    private func commitAdd() {
        let tokens = Self.tokens(from: newExclusion)
        guard !tokens.isEmpty else { return }
        if tokens.count == 1 {
            commitSingle(tokens[0])
        } else {
            let result = store.addExclusions(tokens)
            newExclusion = ""
            feedback = .summary(added: result.added, skipped: result.skipped)
        }
    }

    /// Classifies one token the same way `store.protect` does, clearing the field only on success so a
    /// mistake stays visible to fix.
    private func commitSingle(_ token: String) {
        guard let rule = DomainExclusionRule(token) else {
            feedback = .invalid(token)
            return
        }
        guard !store.preferences.policy.exclusions.contains(rule) else {
            feedback = .duplicate(rule.hostSuffix)
            return
        }
        store.addExclusion(token)
        newExclusion = ""
        feedback = .none
    }

    /// Formats a single-substitution localized string for the caption.
    private func format(_ key: String, _ argument: String) -> String {
        String(format: NSLocalizedString(key, comment: ""), argument)
    }

    /// Formats the two-count batch summary so the caller stays readable.
    private func summaryText(added: Int, skipped: Int) -> String {
        String(format: NSLocalizedString("settings.exclusions.feedback.summary", comment: ""), added, skipped)
    }

    /// Splits raw input into trimmed, non-empty tokens on commas, semicolons, and whitespace so a pasted
    /// or typed batch becomes several rules; host suffixes never contain these separators, so it is safe.
    private static func tokens(from rawValue: String) -> [String] {
        rawValue
            .components(separatedBy: CharacterSet(charactersIn: ",;\n\t "))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

/// Classifies the most recent add attempt so the caption can give precise, non-alarming feedback.
private enum AddFeedback: Equatable {
    /// No attempt yet, or the field was edited since the last result.
    case none
    /// The single typed token was not a valid domain; echoes the raw token back.
    case invalid(String)
    /// The single typed host is already protected; echoes the normalized host back.
    case duplicate(String)
    /// A multi-token batch was added; carries how many landed versus were skipped.
    case summary(added: Int, skipped: Int)
}
