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
- Distribution through a signed and notarized macOS disk image.
- Installation by dragging PineappleWM into `/Applications`.

Release artifacts use the following naming convention:

`PineappleWM-<version>.dmg`

For the first alpha:

`PineappleWM-0.1.0-alpha.1.dmg`

The disk image must contain:

- `PineappleWM.app`
- A symbolic link to `/Applications`

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
8. Sign the application and all embedded executable code with a Developer ID Application certificate.
9.  Create a disk image containing the application and symbolic link to `/Applications`.
10. Sign the disk image with a Developer ID Application certificate.
11. Verify the integrity and signatures of the disk image and application.
12. Submit the disk image to Apple for notarization.
13. Staple and validate te notarization ticket.
14. Generate a SHA-256 checksum.
15. Create a draft GitHub prerelease and attach the DMG and checksum.
16. Download the attached disk image through a browser.
17. Mount it, copy PineappleWM into `/Applications`, and test it on a clean Mac.
18. Publish the GitHub prerelease.
19. Merge any release-only fixes back into `main`.

## Release Requirements

A release must not be published unless:

- CI passes on the tagged commit.
- The application was built from a clean checkout.
- Version and build metadata match the release.
- The application and all embedded executable code have valid Developer ID Applcation signatures
- The disk image has a valid Developer ID Applicaion signature.
- The disk image passes an integrity check.
- Apple notarization succeeds.
- The notarization ticket is stapled to the disk image.
- Gatekeeper accepts the downloaded disk image and application.
- The disk image contains `PineappleWM.app` and a symbolic link to `/Applications`.
- The application launches from `/Applications` on a clean macOS 26 user account.
- Launching directly from the mounted disk image has also been tested.
- Login-item behavior works after copying the applicatoin into `/Applications`.
- The application contains the intended Apple Silicon architecture.
- Installation has been tested using a browser-downloaded disk image.
- The published checksum matches the downloadable artifact.
- Known limitations and uninstallation instructions are included in the release notes.

## Alpha Releases

Alpha releases are unfinished and may contain defects or incomplete functionality.

GitHub alpha releases must be marked as prereleases and must not be presented as stable production releases on the website.
