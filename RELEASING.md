# Releasing DAWN

This document defines how DAWN releases are prepared and distributed

## Distribution

DAWN is distributed through:

- GitHub Releases.
- The official DAWN website.

GitHub Releases is the canonical source for the release artifacts. The website must link to the GitHub artifact or distribute the exact same file and checksum. A release must never be rebuilt separately for the website.

## Supported Platform

The first alpha supports:

- macOS 15.0 or later.
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
- For stable releases, the update-feed publication workflow succeeds.
- For stable releases, the appcast and release notes are accessible through `https://update.opendawn.app`.
- For stable releases, an older signed build discovers the published update.

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

## Update Validation

Every stable update must be validated before its GitHub release and production appcast are published.

Use:

- The exact signed and notarized candidate artifact produced by the Release workflow.
- An older signed and notarized DAWN build with a lower build number.
- An isolated HTTPS validation feed that cannot overwrite the production appcast.
- A clean macOS 26 account or Mac.

Only the older validation build should be configured to use the isolated feed. The candidate must remain identical to the artifact intended for publication.

Malformed feeds and tampered artifacts must never be uploaded to https://update.opendawn.app/appcast.xml.

Record the following information with the draft release:

- Baseline version and build number.
- Candidate version and build number.
- Candidate DMG checksum.
- Test macOS version and architecture.
- Installation location.
- Result of every validation scenario.
- Relevant updater log lines.
- Name of the person who performed the validation and the date.

Do not include signing keys, credentials, complete local paths or unfiltered system logs in the validation record.

### Pre-Publish Checks

Before beginning the update scenarios:

1. Confirm that CI succeeded for the candidate commit.
2. Download the candidate DMG and checksum from the draft release.
3. Confirm that the downloaded checksum matches the published checksum.
4. Verify the DMG integrity, notarization ticket and Gatekeeper assessment.
5. Confirm that the candidate app and embedded agent have valid Developer ID signatures.
6. Inspect the validation appcast and confirm its version, build, URL, length, EdDSA signature, minimum macOS version and release-notes URL.
7. Install and launch the baseline build.
8. Confirm that the baseline build and embedded agent work before testing any update.

### Validation Scenarios

| Scenario | Procedure | Expected result |
|---|---|---|
| Already on latest version | Serve an appcast whose newest compatible build matches the installed build, then check for updates. | DAWN reports that it is up to date and remains usable. |
| Compatible update available | Serve the signed candidate with a higher build number, then check for updates. | DAWN displays the candidate version and allows the download to begin. |
| Offline during check | Disable the network before checking for updates. | DAWN reports a network failure, permits another check and leaves the installed build unchanged. |
| Offline during download | Begin downloading the candidate, disable the network after progress begins, then restore the network. | The download fails safely, DAWN permits retrying and the installed build remains usable. |
| Invalid appcast | Serve malformed XML from the isolated validation feed. | DAWN reports an invalid feed and does not modify the installed build. |
| Invalid EdDSA signature | Copy the candidate archive, modify it after signing, update the appcast length if necessary, but retain the original EdDSA signature. | Sparkle rejects the archive, DAWN reports a verification failure and the installed build remains unchanged. |
| Update requires newer macOS | Set the isolated appcast minimum system version higher than the test Mac version. | DAWN reports that the update requires a newer macOS version and does not download it. |
| User cancels installation | Begin installation and cancel when macOS requests authorization. | DAWN returns to an idle state and the existing installation continues to launch. |
| Installation from `/Applications` | Install the baseline in `/Applications` and complete the update. | The candidate replaces the baseline and launches from `/Applications`. |
| Installation from another writable directory | Install the baseline in a user-writable directory such as `~/Applications` and complete the update. | The candidate replaces the baseline in the same directory and relaunches successfully. |
| Installation requiring authorization | Run the update from a location that is not writable by the current test user and approve the macOS authorization request. | Authorization succeeds, the candidate is installed and no unrelated files are modified. |
| Successful relaunch | Complete an update without interruption. | DAWN relaunches with the expected marketing version and build number. |
| Embedded agent reconnects | After the updated application relaunches, open DAWN and exercise a feature that communicates with the embedded agent. | The embedded agent starts, the event bus reconnects and the feature completes successfully. |

After every failure scenario:

1. Launch the existing DAWN installation.
2. Confirm that its version and build number did not change.
3. Confirm that the embedded agent connects.
4. Confirm that checking for updates can be attempted again.
5. Restore the isolated feed before starting the next scenario.

A release cannot be published if the working installation is damaged, replaced or made unlaunchable by any failed scenario.

### Updater Diagnostics

Use the unified logging system while reproducing update failures:

```sh
log stream \
  --style compact \
  --level info \
  --predicate 'subsystem == "app.opendawn.dawnApp" AND category == "app-lifecycle"'
```

Updater failures must identify one of these stages:

- check
- download
- verification
- installation

The error domain and numeric code may be recorded. Do not record signing secrets, authentication data, complete local paths or unrelated log messages.

## Update Recovery

### Broken Production Feed

If the production appcast is malformed, inaccessible or references the wrong artifact:

1. Stop any pending update-feed publication workflow.
2. Restore the last known-good `appcast.xml` from the Git history of `open-dawn/open-dawn.github.io`.
3. Do not modify or replace an already published artifact under the same tag or filename.
4. Verify that the restored appcast is valid XML and references an available signed artifact.
5. Verify the live appcast and release notes over HTTPS.
6. Check for updates from a signed older build.
7. Record the incident and the Pages commit used for recovery.

Restoring a previous feed is allowed during incident recovery even though normal publication prevents build-number rollback. Do not delete or move the affected Git tag.

### Broken Release

If the appcast is valid but the published update is defective:

1. Restore the last known-good production appcast so additional clients do not discover the defective build.
2. Keep the defective tag and artifacts available for auditing.
3. Add a warning to the affected GitHub release.
4. Fix the problem on a new release branch.
5. Increase the build number and create a new release tag.
6. Build, sign and notarize a new artifact.
7. Repeat every update-validation scenario before publishing the replacement.
8. Publish the corrected release and appcast.
9. Verify that clients on the last known-good build discover the corrected update.

Never reuse a build number, replace an asset in place, move a published tag or generate a different artifact with the same release identity.

### Suspected Signing-Key or Publication-Key Exposure

If an EdDSA private key or Pages deploy key may have been exposed:

1. Stop release and feed-publication workflows.
2. Remove or rotate the affected credential.
3. Restrict the production feed to the last known-good appcast.
4. Preserve workflow logs and release metadata for investigation without copying secrets into the incident record.
5. Coordinate EdDSA key rotation with an application release that embeds the replacement public key.
6. Resume publication only after signed-build validation succeeds with the replacement credentials.

## Release Environment

The `release` GitHub environment defines the `APPLE_TEAM_ID` variable and the following secrets:

- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `APP_STORE_CONNECT_API_KEY_P8_BASE64`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `SPARKLE_ED_PRIVATE_KEY`
- `PAGES_DEPLOY_KEY`

`SPARKLE_ED_PRIVATE_KEY` contains the private EdDSA key exported from Sparkle's `generate_keys` tool using the `app.opendawn` account. The public key is embedded in the application. The exported private key must be transferred directly into the environment secret and its temporary local file removed.

`PAGES_DEPLOY_KEY` contains the private half of a dedicated SSH deploy key. Its public half is registered with write access on `open-dawn/open-dawn.github.io`. The key must not be reused for another repository.
