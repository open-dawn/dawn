# Releasing PineappleWM

This document defines how PineappleWM releases are prepared and distributed

## Distribution

PineappleWM is distributed through:

- GitHub Releases.
- The official PineappleWM website.

GitHub Releases is the canonical source for the release artifacts. The website must link to the GitHub artifact or distribute the exact same file and checksum. A release must never be rebuilt separately for the website.

## Supported Platform

The first alpha supports:

- macOS 26.0 or later.
- Apple Silicon Macs.
- Installation through a signed macOS installer package.

Release artifacts use the following naming convention:

`PineappleWM-<version>.pkg`

For the first alpha:

`PineappleWM-0.1.0-alpha.1.pkg`

## Versioning

PineappleWM uses semantic versioning for Git tags.

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
2. Set the marketing version and build number.
3. Prepare the release notes and update build metadata.
4. Run linting, tests, and the Release build.
5. Merge the release branch into `stable`.
6. Create the release tag on the resulting `stable` commit.
7. Build the application from that tag.
8. Sign the application with a Developer ID Application certificate.
9. Package the application for installation in `/Applications`.
10. Sign the package with a Developer ID Installer certificate.
11. Notarize and staple the final installer package.
12. Generate a SHA-256 checksum.
13. Create a draft GitHub prerelease and attach the PKG and checksum.
14. Download and install the attached package on a clean Mac.
15. Publish the GitHub prerelease.
16. Publish the same package, or a link to it, on the website.
17. Merge any release-only fixes back into `main`.

## Release Requirements

A release must not be on published unless:

- CI passes on the tagged commit.
- The application was built from a clean checkout.
- Version and build metadata match the release.
- The application and all embedded executable code have valid signatures.
- The installer package has a valid Developer ID Installer signature.
- Apple notarization succeeds.
- The notarization ticket is stapled to the installer package.
- Gatekeeper accepts the downloaded installer.
- The package installs PineappleWM into `/Applications`.
- The application launches on a clean macOS 26 user account.
- Login-item behavior has been tested after installation.
- The application contains the intended Apple Silicon architecture.
- Installation has been tested using a browser-downloaded package.
- The published checksum matches the downloadable artifact.
- Known limitations and uninstallation instructions are included in the release notes.

## Alpha Releases

Alpha releases are unfinished and may contain defects or incomplete functionality.

GitHub alpha releases must be marked as prereleases and must not be presented as stable production releases on the website.
