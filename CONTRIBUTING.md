# Contributing to Kkachi

Thanks for your interest. Kkachi is a small, opinionated macOS menu-bar utility, and contributions are
welcome as long as they keep it small, quiet, and trustworthy.

## Building

- macOS with a recent Xcode.
- Open `Kkachi.xcodeproj` and build the `Kkachi` scheme, or:

```sh
xcodebuild test -project Kkachi.xcodeproj -scheme Kkachi -destination 'platform=macOS' \
  -only-testing:KkachiTests
```

The `KkachiTests` unit suite runs without real browsers (browser automation is faked) and should stay
green. `KkachiUITests` drives the app through a deterministic test harness. Real-browser tests are opt-in
and need actual browsers installed.

## Conventions (please read before a PR)

These rules keep Kkachi small, auditable, and safe to change. Some are enforced by tests:

- **Files stay ≤200 lines** (hard ceiling 250). Split before you grow past it.
- **No user-facing string literals in code.** All copy lives in `Kkachi/Resources/Localizable.xcstrings`
  and is referenced by key. New keys must ship in **all five locales** (`en`, `ja`, `ko`, `zh-Hans`,
  `zh-Hant`) — a CI test fails otherwise.
- **Surgical changes.** Touch only what your change requires; match the surrounding style.
- **Every change should be tested** where it can be (the suite is fast and deterministic).
- Document declarations with intent (why it exists, what must stay true), not narration.

## What to propose — and what not to

The fastest way to get a change merged is to respect the product boundaries in the README. Pruning-safety,
durability, accessibility, localization, and browser-compatibility fixes are especially welcome. Features
that turn Kkachi into a tab manager, dashboard, session manager, or command palette will be declined,
however well built — that is a product decision, not a quality judgment.

## Trust-sensitive areas

Changes to any of these get extra review, and should come with tests:

- `Kkachi/Infrastructure/Persistence/RestoreHistoryStore.swift` (durable, private on-disk history)
- `Kkachi/Domain/Tracking/TabTracker+Evaluation.swift` (what gets closed, and the data captured first)
- `Kkachi/Domain/Tracking/PrunedTab.swift` (exactly which fields are persisted)
- the entitlements and `NSAppleEventsUsageDescription` copy

## Maintenance & succession

Kkachi is currently maintained by a single person. To keep a trust utility trustworthy even if that
changes:

- The Apple **Developer ID** signing identity and the **Sparkle update (EdDSA) signing key** are the two
  irreplaceable secrets. They are held by the maintainer and are **not** in this repository. If you are
  taking over maintenance, you must rotate/re-issue these; releases cannot be signed without them.
- If the project goes quiet, that is a **stated maintenance-mode state**, not abandonment — the security
  guarantees in [SECURITY.md](SECURITY.md) still describe intent, and the code remains auditable.
- Forks are welcome under the [MIT license](LICENSE); please change the bundle identifier, app name, and
  update feed so users aren't confused about provenance.
