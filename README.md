# Kkachi

Kkachi is a native macOS menu-bar utility that closes browser tabs you have left idle and keeps a small
local restore history so you can bring them back.

The promise is deliberately narrow: Kkachi reads tab title, URL, and whether audio/video is playing, then
keeps your tab data on your Mac.

## Status

Kkachi is preparing for its first public release. User-installable builds will ship as signed,
notarized DMGs on GitHub Releases and through a Homebrew cask. The planned release path is documented in
[RELEASE.md](RELEASE.md).

After the first notarized release is published, Homebrew installation will be:

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
- whether audio/video is audibly playing

Kkachi does not collect page content, form fields, cookies, local storage, session storage, scroll position,
or DOM text. Its media check returns only playback state so it does not close a tab that is playing.
It makes no network calls today.

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
| Browser automation reads tab title, URL, and media playback state | [`BrowserScriptingBridge.swift`](Kkachi/Infrastructure/Scripting/BrowserScriptingBridge.swift), [`AppleScriptBridge+Media.swift`](Kkachi/Infrastructure/Scripting/AppleScriptBridge+Media.swift) |
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
- a collector of page content, cookies, form state, playback details, or scroll position

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
