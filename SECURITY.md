# Security Policy

Kkachi is a trust utility. Security and privacy issues are treated as product bugs, not paperwork.

## Reporting A Vulnerability

Please report security or privacy issues **privately first**:

- Use GitHub's **Report a vulnerability** flow from this repository's Security tab, or
- email the maintainer listed on the repository owner profile.

Please include what you found, how to reproduce it, and the impact. You will get an acknowledgement, and
a fix or mitigation plan will be shared before public disclosure.

## Highest-Priority Issues

Because Kkachi closes browser tabs, the most serious issues are:

- **Restore loss** - Kkachi closes a tab but fails to keep the restore record it promised.
- **Unsafe pruning** - Kkachi closes an active, protected, media-playing, ambiguous, or unavailable tab.
- **Data over-read** - Kkachi reads page content, form fields, cookies, storage, DOM text, or anything
  beyond the metadata described in [PRIVACY.md](PRIVACY.md).
- **Data exfiltration** - Kkachi sends tab data off the Mac.
- **History weakening** - Kkachi weakens `restore-history.json` protections, such as file permissions,
  backup exclusion, Spotlight exclusion, capping, or corruption handling.

## How Kkachi Limits Its Blast Radius

- Kkachi runs non-sandboxed under the hardened runtime and requests only the Apple Events automation
  entitlement it needs for browser control.
- Per-browser automation is granted by the user through the macOS Automation privacy prompt and can be
  revoked in System Settings at any time.
- Browser metadata reads are limited to URL, title, active state, media playback state, and in-memory
  identifiers needed to target the correct tab.
- The media probe runs minimal browser JavaScript that returns only whether audible audio/video is playing.
- Failed or unavailable automation goes in the safe direction: Kkachi keeps the tab open.

## Browser Automation Fragility

Kkachi drives browsers through Apple Events and ScriptingBridge. Browser updates can change or break that
automation. When that happens, Kkachi should degrade quietly for the affected browser instead of acting
unpredictably.

If you notice Kkachi silently stop working after a browser update, please report it.

## Supported Versions

Until the first `1.0` release is published, only the latest released version receives security fixes.
