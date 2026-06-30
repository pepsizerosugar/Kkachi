# Privacy

Kkachi's whole reason to exist is trust. This document states what the app reads, what it writes, what it
never touches, and where to verify those claims in the source.

## Short Version

**Your tabs and browsing data stay on your Mac.** Kkachi has no accounts, servers, analytics, or telemetry
today. The only durable tab data it keeps is a capped local restore history.

## What Kkachi Reads

To find tabs that have been left idle, Kkachi uses macOS Apple Events for supported browsers you allow in
System Settings. It reads only the tab metadata needed for pruning and restore:

- the tab's address (URL)
- the tab's title
- whether the tab is currently active
- whether an audio or video element is audibly playing
- browser/window/tab identifiers needed in memory to target the right tab safely

The media check returns only `playing`, `notPlaying`, or unavailable/error state. It exists so Kkachi does
not close a tab that is making sound.

## What Kkachi Does Not Read

Kkachi does not collect:

- page content, DOM text, or document structure
- form fields or anything you have typed
- cookies, local storage, or session storage
- scroll position
- browser history beyond currently open tabs
- data from browsers you have not connected

For media safety, Kkachi runs a minimal browser JavaScript command that asks only whether audible
`audio` or `video` elements exist. It does not return page text, element contents, cookies, forms, local
storage, or arbitrary JavaScript state. If that check is unavailable, Kkachi keeps the tab open.

## What Kkachi Stores

When Kkachi closes a tab, it saves enough metadata to show and reopen that page later:

```json
{
  "schemaVersion": 1,
  "savedAt": "ISO-8601 timestamp",
  "tabs": [
    {
      "id": "restore row UUID",
      "url": "https://example.com/",
      "title": "Example",
      "prunedAt": "ISO-8601 timestamp",
      "batchID": "UUID shared by tabs closed in one pruning pass",
      "browserID": "safari",
      "browserNameKey": "browser.safari"
    }
  ]
}
```

Kkachi does **not** persist the original browser window ID, browser tab ID, Safari tab index, or any
diagnostic tab identity. Those are used in memory while pruning and are dropped before restore history is
written to disk. Restore reopens the saved URL in the origin browser when possible.

Restore history is stored at:

```text
~/Library/Application Support/Kkachi/restore-history.json
```

Properties of that file:

- **Local only** - it is never uploaded anywhere.
- **Capped** - only the newest 30 entries are kept.
- **Atomic writes** - it is not left half-written.
- **Owner-only permissions** - the directory is `0700` and the file is `0600`.
- **Excluded from backup** - the file is marked out of Time Machine/iCloud backup.
- **Skipped by Spotlight** - the directory gets a `.metadata_never_index` marker.
- **Corruption-safe** - a damaged file is quarantined as `restore-history.corrupt.json` and Kkachi starts
  from empty instead of crashing.

Settings such as threshold, paused state, protected sites, enabled browsers, and language are stored
separately in `UserDefaults`.

## Encryption At Rest

The restore history file is **not encrypted at rest in v1**. Its file permissions and backup/indexing
flags protect against casual local or backup inspection, not a determined attacker with access to your
unlocked user account.

Clearing restore history from Settings removes the saved restore records.

## Network Access

Today Kkachi itself makes **no network requests at all**. Restoring a tab asks the origin browser to open
the saved URL; any page loading after that is browser behavior, not telemetry from Kkachi.

When automatic updates ship, the app may check a published Sparkle appcast for new versions. That update
check will be disclosed, opt-out, and unrelated to your tabs or usage. Kkachi will not add telemetry or
analytics.

## Verify It Yourself

The relevant source files are intentionally small:

- Storage and on-disk privacy: `Kkachi/Infrastructure/Persistence/RestoreHistoryStore.swift`
- What is captured before closing a tab: `Kkachi/Domain/Tracking/TabTracker+Evaluation.swift`
- Exactly which tab fields are persisted: `Kkachi/Domain/Tracking/PrunedTab.swift`
- Browser metadata reads: `Kkachi/Infrastructure/Scripting/BrowserScriptingBridge.swift`
- Media playback probe: `Kkachi/Infrastructure/Scripting/AppleScriptBridge+Media.swift`
- Permission scope and consent copy: `Kkachi/Resources/InfoPlist.xcstrings`

If you find anything that contradicts this document, please open an issue. For private security or
privacy reports, use the process in [SECURITY.md](SECURITY.md).
