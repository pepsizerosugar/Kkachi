# Kkachi

<p align="center">
  <img src="site/assets/kkachi-icon.png" alt="Kkachi app icon" width="112" height="112">
</p>

<p align="center">
  <strong>For tabs you were definitely going to close.</strong>
</p>

<p align="center">
  Kkachi is a tiny native macOS menu-bar app that tucks away idle browser tabs and keeps a small local
  restore history, just in case Future You was right.
</p>

<p align="center">
  <a href="https://github.com/pepsizerosugar/Kkachi/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/pepsizerosugar/Kkachi/actions/workflows/ci.yml/badge.svg"></a>
  <img alt="Platform: macOS 13+" src="https://img.shields.io/badge/platform-macOS%2013%2B-101216">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-236b62">
  <img alt="Telemetry: none" src="https://img.shields.io/badge/telemetry-none-b3312a">
</p>

## Status

Kkachi is preparing for its first public release. User-installable builds will ship as signed,
notarized DMGs on [GitHub Releases](https://github.com/pepsizerosugar/Kkachi/releases) and through a
Homebrew cask.

After the first notarized release is published:

```sh
brew install --cask pepsizerosugar/tap/kkachi
```

Until then, you can build it locally with Xcode.

## Why Kkachi

Most tabs are not work. They are postponed decisions wearing browser chrome.

Kkachi watches supported browsers, closes only tabs that have been idle long enough, and leaves a local
way back. No tab shame. Just a smaller tab strip.

## What It Does

| Step | Behavior |
| --- | --- |
| Watch | Reads open tab metadata - URL, title, active state, and audible media state - through macOS Apple Events. |
| Prune | Closes only inactive tabs that pass the pruning policy. Active, protected, media-playing, ambiguous, or unavailable tabs are skipped. |
| Restore | Keeps a capped local history of recently pruned tabs and reopens them in their original browser when possible. |

Supported browsers are Safari, Google Chrome, Microsoft Edge, Naver Whale, Brave, Vivaldi, Opera, and
Arc.

## Privacy Promise

Kkachi's privacy promise is deliberately small and verifiable:

| Kkachi | Details |
| --- | --- |
| Reads | Tab URL, tab title, active tab state, and whether audio/video is audibly playing. |
| Stores | Minimal restore metadata: URL, title, prune time, browser identifiers/display key, and row/batch IDs. |
| Does not read | Page content, DOM text, form fields, cookies, local storage, session storage, scroll position, or browsing history beyond currently open tabs. |
| Does not send | Anything about your tabs off your Mac. Kkachi itself makes no network requests today, and has no accounts, servers, analytics, or telemetry. |

Restore history is stored locally at:

```text
~/Library/Application Support/Kkachi/restore-history.json
```

See [PRIVACY.md](PRIVACY.md) for the full storage model, including what is written to disk and what is
intentionally not encrypted in v1.

## Build From Source

Requirements:

- macOS 13 or later
- Xcode

Open `Kkachi.xcodeproj` and run the `Kkachi` scheme, or build from the command line:

```sh
xcodebuild build -project Kkachi.xcodeproj -scheme Kkachi -destination 'platform=macOS'
```

Run the deterministic test suite:

```sh
xcodebuild test -project Kkachi.xcodeproj -scheme Kkachi -destination 'platform=macOS'
```

## Verify The Claims

Kkachi is intentionally small so its trust claims can be checked in source.

| Claim | Source |
| --- | --- |
| Supported browsers and automation families | [`SupportedBrowsers.swift`](Kkachi/Domain/Browser/SupportedBrowsers.swift) |
| Pruning avoids active, protected, media-playing, ambiguous, or unavailable tabs | [`PruneEvaluator.swift`](Kkachi/Domain/Tracking/PruneEvaluator.swift) |
| Persisted restore-history fields omit original tab/window identity | [`PrunedTab.swift`](Kkachi/Domain/Tracking/PrunedTab.swift) |
| History is local, capped, private, atomic, and corruption-safe | [`RestoreHistoryStore.swift`](Kkachi/Infrastructure/Persistence/RestoreHistoryStore.swift) |
| Browser automation reads title, URL, active state, and media playback state | [`BrowserScriptingBridge.swift`](Kkachi/Infrastructure/Scripting/BrowserScriptingBridge.swift), [`AppleScriptBridge+Media.swift`](Kkachi/Infrastructure/Scripting/AppleScriptBridge+Media.swift) |
| Apple Events permission copy | [`InfoPlist.xcstrings`](Kkachi/Resources/InfoPlist.xcstrings) |

## Product Boundaries

Kkachi is not trying to become a browser extension, full tab manager, session manager, bookmark
replacement, productivity dashboard, or search palette for tabs.

Changes that improve safety, reliability, accessibility, localization, browser compatibility, release
quality, and native macOS behavior are in scope. Features that widen the privacy surface or turn the app
into a tab-management dashboard are out of scope.

## Contributing

Kkachi is small, opinionated, and trust-sensitive. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before
opening a pull request.

## Website

The GitHub Pages site lives in [`site/`](site/) and is deployed by
[`.github/workflows/pages.yml`](.github/workflows/pages.yml).

## Security

Please report security or privacy issues privately first. See [SECURITY.md](SECURITY.md).

## License

Kkachi is released under the [MIT License](LICENSE).
