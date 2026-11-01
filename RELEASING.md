# Releasing DAWN

This document defines how DAWN releases are prepared and distributed

## Distribution

DAWN is distributed through:

- GitHub Releases.
- The official DAWN website.

GitHub Releases is the canonical source for the release artifacts. The website must link to the GitHub artifact or distribute the exact same file and checksum. A release must never be rebuilt separately for the website.

## Supported Platform

The first alpha supports:

- macOS 26.0 or later.
- Apple Silicon Macs.
- Distribution through a signed and notarized macOS disk image.
- Installation by dragging DAWN into `/Applications`.

Release artifacts use the following naming convention:

`DAWN-<version>.dmg`

For the first alpha:

`DAWN-0.1.0-alpha.1.dmg`

The disk image must contain:

- `DAWN.app`
- A symbolic link to `/Applications`

## Versioning

DAWN uses semantic versioning for Git tags.

The first alpha release is:

- Release version: `0.1.0`
- Git tag: `v0.1.0-alpha.1`
- Marketing version: `0.1.0`
- Initial build number: `1`

The prerelease identifier belongs in the Git tag, not in the macOS marketing version.

Build numbers must increase for every release artifact. A corrected build must receive a new build number and release tag.

Examples:

- `v0.1.0-alpha.1`
- `v0.1.0-alpha.2`
- `v0.1.0-beta.1`
- `v0.1.0`

Published tags must never be moved, reused or deleted. If a release contains a problem, create a new version.

## Branches

### `main`

`main` contains ongoing development and completed features intended for future releases.

Feature and fix branches are merged into `main` through pull requests.

### `release/*`

Release branches are temporary branches created from `main` for stabilization.

Example:

`release/0.1.0-alpha.1`

Only release preparation and necessary fixes should be added after the branch is created.

### `stable`

`stable` represents the source of the latest published release.

Development work must not be committed directly to `stable`. Release branches are merged into it only after their tests and release checks pass.

Every published release tag must point to the exact commit released from `stable`.

## Release Process

1. Create a `release/*` branch from the selected commit on `main`.
2. Set the marketing version and a build number greater than the currently published build.
3. Prepare the release notes and update build metadata.
4. Run linting, tests, and the Release build.
5. Merge the release branch into `stable`.
6. Run the Release workflow manually from `stable` using the intended release tag.
7. Inspect the dry-run DMG, checksum, appcast and HTML release notes.
8. Install the dry-run DMG and verify the application, embedded agent, login item and update UI.
9. Create and push the release tag from the exact `stable` commit.
10. The Release workflow builds and signs the complete application bundle.
11. The workflow creates and signs the DMG, submits it for notarization, and staples the notarization ticket.
12. The workflow generates the checksum, release notes and signed Sparkle appcast.
13. The workflow validates the appcast metadata and ensures the build number is greater than the published build.
14. The workflow creates a draft GitHub release containing the DMG, checksum, appcast and HTML release notes.
15. Download the draft release DMG, install it on a clean Mac and complete the release requirements.
16. Publish the GitHub release.
17. For stable releases, the update-feed workflow publishes the appcast and release notes to `open-dawn/open-dawn.github.io`.
18. Verify `https://update.opendawn.app/appcast.xml` and the release-notes URL over HTTPS.
19. Launch an older signed DAWN build and confirm it discovers the newly published build.
20. Verify that DAWN downloads and validates the published update.
21. Merge any release-only fixes back into `main`.

## Release Requirements

A release must not be considered complete unless:

- CI passes on the tagged commit.
- The application was built from a clean checkout.
- Version and build metadata match the release.
- The application and all embedded executable code have valid Developer ID Application signatures
- The disk image has a valid Developer ID Application signature.
- The disk image passes an integrity check.
- Apple notarization succeeds.
- The notarization ticket is stapled to the disk image.
- Gatekeeper accepts the downloaded disk image and application.
- The disk image contains `DAWN.app` and a symbolic link to `/Applications`.
- The application launches from `/Applications` on a clean macOS 26 user account.
- Launching directly from the mounted disk image has also been tested.
- Login-item behavior works after copying the application into `/Applications`.
- The application contains the intended Apple Silicon architecture.
- Installation has been tested using a browser-downloaded disk image.
- The published checksum matches the downloadable artifact.
- Known limitations and uninstallation instructions are included in the release notes.
- The appcast contains the expected display version, build version, download URL, file size, EdDSA signature, minimum macOS version and release notes.
- The published build number is greater than the previous appcast build.
- The update-feed publication workflow succeeds.
- The appcast and release notes are accessible through `https://update.opendawn.app`.
- An older signed build discovers the published update.

## Alpha Releases

Alpha releases are unfinished and may contain defects or incomplete functionality.

GitHub alpha releases must be marked as prereleases and must not be presented as stable production releases on the website.

## Update Distribution

Stable updates are published through Sparkle.

- Feed: `https://update.opendawn.app/appcast.xml`
- Archives: GitHub Release assets
- Release notes: `https://update.opendawn.app/releases/`
- Pages repository: `open-dawn/open-dawn.github.io`

The release workflow generates the signed appcast and attaches it to a draft GitHub release. Publishing a stable GitHub release triggers the update-feed workflow, which copies the appcast and release notes to GitHub Pages.

Prereleases do not update the stable feed. Sparkle channels must be implemented before alpha, beta or release-candidate builds can be offered through the updater.

## Release Environment

The `release` GitHub environment contains:

- `APPLE_TEAM_ID`
- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `APP_STORE_CONNECT_API_KEY_P8_BASE64`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `SPARKLE_ED_PRIVATE_KEY`
- `PAGES_DEPLOY_KEY`

`SPARKLE_ED_PRIVATE_KEY` contains the private EdDSA key exported from Sparkle's `generate_keys` tool using the `app.opendawn` account. The public key is embedded in the application. The exported private key must be transferred directly into the environment secret and its temporary local file removed.

`PAGES_DEPLOY_KEY` contains the private half of a dedicated SSH deploy key. Its public half is registered with write access on `open-dawn/open-dawn.github.io`. The key must not be reused for another repository.
