# Contributing To Kkachi

Thanks for your interest. Kkachi is a small, opinionated macOS menu-bar utility, and contributions are
welcome when they keep it small, quiet, and trustworthy.

## Start Here

Good changes usually improve one of these:

- pruning safety
- restore reliability
- browser compatibility
- privacy and storage durability
- accessibility
- localization
- native macOS behavior
- release and testing quality

Features that turn Kkachi into a full tab manager, session manager, bookmark replacement, productivity
dashboard, browser extension, or tab search palette are out of scope. That boundary keeps the privacy
surface small.

## Build And Test

Requirements:

- macOS 13 or later
- Xcode

Open `Kkachi.xcodeproj` and build the `Kkachi` scheme, or run:

```sh
xcodebuild build -project Kkachi.xcodeproj -scheme Kkachi -destination 'platform=macOS'
```

Run the full deterministic suite before sending a PR:

```sh
xcodebuild test -project Kkachi.xcodeproj -scheme Kkachi -destination 'platform=macOS'
```

For a faster unit-only loop:

```sh
xcodebuild test -project Kkachi.xcodeproj -scheme Kkachi -destination 'platform=macOS' \
  -only-testing:KkachiTests
```

`KkachiTests` fakes browser automation. `KkachiUITests` drives the app through a deterministic harness.
Real-browser checks are opt-in and require the actual browsers to be installed.

## Code Conventions

These rules keep Kkachi auditable:

- **Files stay <=200 lines** where possible, with a hard ceiling of 250. Split before a file becomes hard
  to review.
- **No user-facing string literals in code.** Visible copy belongs in
  `Kkachi/Resources/Localizable.xcstrings`.
- **All localized keys ship in five locales:** `en`, `ja`, `ko`, `zh-Hans`, and `zh-Hant`.
- **Surgical changes only.** Touch the smallest set of files needed for the behavior.
- **Tests should match the risk.** Trust-sensitive changes need tests.
- **Comments explain intent.** Prefer why something must stay true over narrating what a line does.

## Trust-Sensitive Areas

Changes to these areas get extra review and should include focused tests:

- `Kkachi/Infrastructure/Persistence/RestoreHistoryStore.swift` - local, private, durable restore history
- `Kkachi/Domain/Tracking/TabTracker+Evaluation.swift` - what gets captured before a tab is closed
- `Kkachi/Domain/Tracking/PruneEvaluator.swift` - which tabs are eligible to close
- `Kkachi/Domain/Tracking/PrunedTab.swift` - exactly which fields are persisted
- entitlements and `NSAppleEventsUsageDescription` copy

## Documentation Expectations

If a change affects what Kkachi reads, stores, sends, closes, restores, installs, or supports, update the
public docs in the same PR:

- [README.md](README.md) for the first-reader summary
- [PRIVACY.md](PRIVACY.md) for data and storage guarantees
- [SECURITY.md](SECURITY.md) for reporting and threat boundaries
- [RELEASE.md](RELEASE.md) for maintainer release flow

## Maintenance And Succession

Kkachi is currently maintained by a single person. The Apple Developer ID signing identity and the future
Sparkle update signing key are the two irreplaceable release secrets. They are not stored in this
repository.

If you take over maintenance, rotate or re-issue those secrets. If you fork Kkachi, change the bundle
identifier, app name, and update feed so users are not confused about provenance.
