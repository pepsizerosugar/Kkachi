# Kkachi

Kkachi is a native macOS menu-bar utility that closes browser tabs you have left idle and keeps a small
local restore history so you can bring them back.

The promise is deliberately narrow: Kkachi reads tab title and URL, never page content, and keeps your tab
data on your Mac.

## Status

Kkachi is preparing for its first public release. Until a signed and notarized build is attached to
GitHub Releases, build from source with Xcode. The planned release path is documented in
[RELEASE.md](RELEASE.md).

```sh
xcodebuild test -project Kkachi.xcodeproj -scheme Kkachi -destination 'platform=macOS'
```

After the first notarized release is published, install with Homebrew:

```sh
brew install --cask pepsizerosugar/tap/kkachi
```

## What It Does

- Watches supported browsers through macOS Apple Events.
- Tracks when each visible tab was last active.
- Closes only inactive tabs that pass the pruning policy.
- Skips active, protected, ambiguous, or unavailable tabs.
- Stores a capped restore history locally.
- Restores pruned tabs in their original browser when possible.

## Privacy

Kkachi reads only:

- tab URL
- tab title

Kkachi never reads page content, form fields, cookies, local storage, session storage, JavaScript state, or
scroll position. It makes no network calls today.

Restore history is stored at:

```text
~/Library/Application Support/Kkachi/restore-history.json
```

See [PRIVACY.md](PRIVACY.md) for the full storage model.

## Verify The Claims

| Claim | Source |
| --- | --- |
| Persisted fields are URL/title/browser/time only | [`PrunedTab.swift`](Kkachi/Domain/Tracking/PrunedTab.swift) |
| History is local, capped, private, and atomic | [`RestoreHistoryStore.swift`](Kkachi/Infrastructure/Persistence/RestoreHistoryStore.swift) |
| Pruning decisions avoid active/protected/ambiguous tabs | [`PruneEvaluator.swift`](Kkachi/Domain/Tracking/PruneEvaluator.swift) |
| Browser automation reads tab title and URL | [`BrowserScriptingBridge+Commands.swift`](Kkachi/Infrastructure/Scripting/BrowserScriptingBridge+Commands.swift) |
| Apple Events permission copy | [`InfoPlist.xcstrings`](Kkachi/Resources/InfoPlist.xcstrings) |

## Build

Requirements:

- macOS
- Xcode

Open `Kkachi.xcodeproj` and run the `Kkachi` scheme, or use:

```sh
xcodebuild build -project Kkachi.xcodeproj -scheme Kkachi -destination 'platform=macOS'
```

Run the deterministic test suite:

```sh
xcodebuild test -project Kkachi.xcodeproj -scheme Kkachi -destination 'platform=macOS'
```

## Product Boundaries

Kkachi is not intended to become:

- a browser extension
- a full tab manager
- a session manager
- a bookmark replacement
- a productivity dashboard
- a search or command palette for tabs
- a collector of page content, cookies, form state, or scroll position

Changes that improve safety, reliability, accessibility, localization, browser compatibility, and native
macOS behavior are in scope. Features that widen the privacy surface or turn the app into a tab-management
dashboard are out of scope.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Website

The GitHub Pages site lives in [`site/`](site/) and is deployed by
[`.github/workflows/pages.yml`](.github/workflows/pages.yml).

## Security

Please report security or privacy issues privately first. See [SECURITY.md](SECURITY.md).

## License

Kkachi is released under the [MIT License](LICENSE).
