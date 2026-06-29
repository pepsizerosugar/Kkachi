# Privacy

Kkachi's whole reason to exist is trust, so its privacy promise is small and verifiable. This document
states exactly what is stored, what is never read, and where you can confirm it in the source.

## The short version

**Your tabs and browsing data never leave your Mac.** Kkachi has no servers, no accounts, and no
analytics. Everything it keeps stays in a local file you can read.

## What Kkachi reads

To find tabs that have been left idle, Kkachi reads — through macOS Apple Events, only from browsers you
connect — the two things it needs:

- the tab's **address (URL)**
- the tab's **title**

That's all. It uses these to decide which inactive tabs are safe to close.

## What Kkachi never reads

- Page content, text, or the DOM
- Form fields or anything you've typed
- Cookies, local storage, or session storage
- JavaScript state, scroll position, or history beyond open tabs
- Anything from browsers you have not connected

It never injects scripts into pages. The "Safely less" principle is deliberate: a smaller promise that
works reliably beats a larger one that depends on fragile page access.

## What Kkachi stores, and where

When Kkachi closes (prunes) an idle tab, it saves a minimal restore record so you can bring it back:

```
{ url, title, browser, prunedAt }
```

These are written to a single local file:

```
~/Library/Application Support/Kkachi/restore-history.json
```

Properties of that file:

- **Local only** — it is never uploaded anywhere.
- **Atomic writes** — it can't be left half-written.
- **Owner-only permissions** (`0600`) — other user accounts can't read it.
- **Excluded from Time Machine / iCloud backup.**
- **Marked to be skipped by Spotlight indexing.**
- **Capped at the newest 30 entries.**
- **Corruption-safe** — a damaged file is quarantined and Kkachi starts from empty rather than crashing.

The original window/tab identity is kept only in memory for the current session and is **never** written
to disk. Settings (threshold, paused, protected sites, enabled browsers) are stored separately in
`UserDefaults`.

### Encryption at rest

The history file is **not encrypted at rest in v1**. This protects against casual disk or backup
inspection, not a determined attacker with access to your unlocked user account. Clearing restore history
(Settings → Privacy) removes the data.

## Network access

Today Kkachi makes **no network calls at all**.

When automatic updates ship, the app will check a published appcast for new versions — that single update
check is the only network request it will ever make, it will be **disclosed and opt-out**, and it carries
no information about your tabs or usage. Kkachi will never add telemetry or analytics.

## Verify it yourself

Because the repository is open and every source file is kept under 200 lines, you can confirm all of the
above by reading the code:

- Storage and on-disk privacy: `Kkachi/Infrastructure/Persistence/RestoreHistoryStore.swift`
- What is captured before closing a tab: `Kkachi/Domain/Tracking/TabTracker+Evaluation.swift`
- Exactly which fields are persisted: `Kkachi/Domain/Tracking/PrunedTab.swift`
- Permission scope and the consent copy: `Kkachi/Resources/InfoPlist.xcstrings`

If you find anything that contradicts this document, please open an issue — that's a bug in the most
important feature Kkachi has.
