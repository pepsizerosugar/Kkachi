# Security Policy

Kkachi is a trust utility, so security and privacy reports are treated as first-class bugs.

## Reporting a vulnerability

Please report security issues **privately** first, rather than opening a public issue:

- Use GitHub's **"Report a vulnerability"** (Security → Advisories) on this repository, or
- email the maintainer (see the profile on the repository owner account).

Include what you found, how to reproduce it, and the impact. You'll get an acknowledgement, and a fix or
mitigation plan will be shared before any public disclosure.

## Scope that matters most

Because of what Kkachi does, the highest-severity issues are:

- Anything that causes Kkachi to **lose a pruned tab** it claimed to keep.
- Anything that closes a tab it should not have (active, protected, or ambiguous).
- Anything that reads **more than the URL and title** of a tab, or sends any tab data off the device.
- Anything that weakens the on-disk protections of `restore-history.json` (permissions, backup/Spotlight
  exclusion).

See [PRIVACY.md](PRIVACY.md) for the exact data and storage model these guarantees rest on.

## How Kkachi limits its own blast radius

- It runs **non-sandboxed under the hardened runtime**, requesting only
  `com.apple.security.automation.apple-events`. Per-browser automation is granted by you through the
  macOS Automation privacy prompt and can be revoked in System Settings at any time.
- It reads only tab address and title; it never injects scripts or reads page content.
- A failed close leaves the tab open (the safe direction); a browser that fails to automate is degraded
  on its own without disabling the rest.

## A note on browser automation fragility

Kkachi drives browsers through Apple Events. A browser update can change or break that automation. When
that happens Kkachi goes quiet for the affected browser rather than acting unpredictably — but if you
notice it silently stop working after a browser update, that is worth reporting.

## Supported versions

Until a `1.0` release, only the latest released version receives security fixes.
