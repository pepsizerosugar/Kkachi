# Releasing Kkachi

Kkachi ships by direct macOS distribution, not through the Mac App Store. The app needs Apple Events
automation for supported browsers, so public builds are Developer ID-signed, Apple-notarized DMGs
published on GitHub Releases.

## Channels

- **Primary:** GitHub Releases with a notarized `Kkachi-<version>.dmg` and `.sha256` file.
- **Secondary:** Homebrew cask pointing to the same GitHub Release DMG.
- **Later:** Sparkle 2 auto-updates after direct downloads and Homebrew are stable.

## CI

`.github/workflows/ci.yml` runs on pull requests, pushes to `main`, and manual dispatch. It verifies:

- the full deterministic XCTest/XCUITest suite
- a Release configuration build with code signing disabled

CI intentionally uses no Apple secrets. It proves the public source tree builds and tests; it does not
produce a trusted user-installable app.

## Release Workflow

`.github/workflows/release.yml` runs when a `v*` tag is pushed. The workflow:

1. archives the app
2. exports it with a Developer ID Application certificate
3. verifies the tag version matches `CFBundleShortVersionString`
4. creates a DMG
5. submits the DMG to Apple notarization
6. staples and validates the notarization ticket
7. uploads the DMG and SHA-256 file to GitHub Releases
8. updates the Homebrew tap cask when `HOMEBREW_TAP_TOKEN` is configured

The workflow rejects a tag whose version does not match the built app version.

## Required Secrets

For the notarized GitHub Release:

- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `MACOS_CERTIFICATE_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `MACOS_KEYCHAIN_PASSWORD`

`MACOS_CERTIFICATE_BASE64` is a base64-encoded `.p12` export of the Developer ID Application certificate
and private key.

For automatic Homebrew tap publishing:

- `HOMEBREW_TAP_TOKEN`

`HOMEBREW_TAP_TOKEN` needs contents write access to `pepsizerosugar/homebrew-tap`. If it is missing, the
release still publishes the GitHub Release and skips only the Homebrew cask update.

## Cut A Release

1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Kkachi.xcodeproj`.
2. Verify locally:

   ```sh
   xcodebuild test -project Kkachi.xcodeproj -scheme Kkachi -destination 'platform=macOS'
   xcodebuild build -project Kkachi.xcodeproj -scheme Kkachi -configuration Release \
     -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
   ```

3. Commit the version bump.
4. Tag and push:

   ```sh
   git tag v1.0
   git push origin v1.0
   ```

5. Confirm the release workflow uploaded `Kkachi-1.0.dmg` and `Kkachi-1.0.dmg.sha256`.
6. Confirm the Homebrew tap update, then test installation:

   ```sh
   brew install --cask pepsizerosugar/tap/kkachi
   ```

## Homebrew Cask

Create `pepsizerosugar/homebrew-tap` before the first public release. The release workflow checks out that
tap and writes `Casks/kkachi.rb` with `scripts/homebrew/write-cask.sh`.

The generated cask should have this shape:

```ruby
cask "kkachi" do
  version "1.0"
  sha256 "PUT_DMG_SHA256_HERE"

  url "https://github.com/pepsizerosugar/Kkachi/releases/download/v#{version}/Kkachi-#{version}.dmg"
  name "Kkachi"
  desc "Tucks away idle browser tabs you keep meaning to close"
  homepage "https://github.com/pepsizerosugar/Kkachi"

  livecheck do
    url "https://github.com/pepsizerosugar/Kkachi"
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"
  app "Kkachi.app"

  zap trash: [
    "~/Library/Application Support/Kkachi",
    "~/Library/Preferences/io.github.pepsizerosugar.Kkachi.plist",
  ]
end
```

Use the personal tap first if upstream `homebrew/homebrew-cask` review would slow the first release. Once
the cask is accepted upstream, update the website and README install command from:

```sh
brew install --cask pepsizerosugar/tap/kkachi
```

to:

```sh
brew install --cask kkachi
```

## Sparkle

Do not block the first public release on Sparkle. Add Sparkle after direct downloads and Homebrew work:

1. Add Sparkle 2.
2. Generate and secure the Sparkle EdDSA signing key.
3. Add `SUPublicEDKey` and `SUFeedURL`.
4. Publish a signed appcast entry for each release.
5. Update [PRIVACY.md](PRIVACY.md), [README.md](README.md), and the website to disclose the update check.
