import AppKit
import libdawnUI
import SwiftUI

struct AboutView<Updater: AppUpdating>: View {
    let content: AboutContent
    let updater: Updater

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 0)

            VStack(spacing: 32) {
                VStack(alignment: .trailing, spacing: 0) {
                    LogoComplete.image(height: 78)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("DAWN")

                    versionLabel
                }

                descriptionLabel
            }

            Spacer(minLength: 0)

            VStack(spacing: 16) {
                HStack(alignment: .bottom, spacing: 8) {
                    DButton(style: .primary) {
                        NSWorkspace.shared.open(feedbackIssueURL)
                    } content: {
                        Text("Give us feedback")
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityHint(
                        "Opens a feedback form in your browser"
                    )

                    updateControls
                        .frame(maxWidth: .infinity)
                }

                Text(content.ticket.copyright)
                    .font(DawnTextStyle.primary)
                    .foregroundStyle(DawnColors.secondaryForeground)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(minWidth: 512, maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background {
            DawnColors.primaryBackground
        }
    }
}

extension AboutView {
    private var shortCommitSHA: String {
        String(content.ticket.commit.sha.prefix(7))
    }

    private var versionLabel: some View {
        (
            Text("Version ")
                .font(DawnTextStyle.primary)
            + Text(content.appVersion)
                .font(DawnTextStyle.primaryBold)
            + Text(" (\(shortCommitSHA))")
                .font(DawnTextStyle.primary)
        )
        .foregroundStyle(DawnColors.primaryForeground)
        .onTapGesture {
            NSWorkspace.shared.open(content.ticket.commit.url)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the commit in your browser")
    }

    private var descriptionLabel: some View {
        VStack(spacing: 0) {
            Text("Dawn is a workspace navigator for macOS")
                .font(DawnTextStyle.primary)

            (
                Text("it is open-source, under the ")
                    .font(DawnTextStyle.primary)
                + Text("\(content.ticket.license) License")
                    .font(DawnTextStyle.primaryBold)
                    .underline()
            )
            .onTapGesture {
                NSWorkspace.shared.open(content.ticket.licenseURL)
            }
            .accessibilityAddTraits(.isLink)
            .accessibilityHint("Opens the license in your browser")
        }
        .foregroundStyle(DawnColors.primaryForeground)
        .multilineTextAlignment(.center)
    }

    private var feedbackIssueURL: URL {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let macosVersion = [
            version.majorVersion,
            version.minorVersion,
            version.patchVersion,
        ]
        .map(String.init)
        .joined(separator: ".")

        return content.ticket.feedbackIssueURL(
            appVersion: content.appVersion,
            macosVersion: macosVersion
        )
    }

    @ViewBuilder
    private var updateControls: some View {
        switch updater.state {
        case .idle:
            updatePanel {
                Color.clear
                    .accessibilityHidden(true)
            } action: {
                checkButton(title: "Check for updates")
            }

        case .checking:
            updatePanel {
                statusText("Looking for available updates...")
            } action: {
                disabledProgressButton(title: "Checking for updates")
            }

        case .updateUnavailable(let reason):
            updatePanel {
                statusText(unavailabilityMessage(for: reason))
            } action: {
                checkButton(title: "Check again")
            }

        case .updateAvailable(let update):
            updatePanel {
                releaseNotesControl(for: update)
            } action: {
                DButton(style: .accent) {
                    updater.installAvailableUpdate()
                } content: {
                    Text("Update now")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel("Update to version \(update.displayVersion)")
            }

        case .downloading(let update, let progress):
            updatePanel {
                statusText("Downloading version \(update.displayVersion)")
            } action: {
                updateProgress(progress, title: "Downloading update")
            }

        case .extracting(let update, let progress):
            updatePanel {
                statusText(
                    "Preparing version \(update.displayVersion)..."
                )
            } action: {
                updateProgress(progress, title: "Preparing update")
            }

        case .readyToInstall(let update):
            updatePanel {
                releaseNotesControl(for: update)
            } action: {
                DButton(style: .accent) {
                    Task {
                        await updater.installAndRelaunch()
                    }
                } content: {
                    Text("Install and relaunch")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel("Install version \(update.displayVersion) and relaunch Dawn")
            }

        case .installing(let update):
            updatePanel {
                statusText("Installing version \(update.displayVersion)...")
            } action: {
                disabledProgressButton(
                    title: "Installing update"
                )
            }

        case .failed(let reason):
            updatePanel {
                statusText(failureMessage(for: reason))
            } action: {
                checkButton(title: "Try again")
            }

        }
    }

    private func updatePanel<Status: View, Action: View>(
        @ViewBuilder status: () -> Status,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(spacing: 4) {
            status()
                .frame(maxWidth: .infinity, minHeight: 16, maxHeight: 36)

            action()
                .frame(maxWidth: .infinity)
        }
    }

    private func checkButton(title: String) -> some View {
        DButton(style: .primary) {
            updater.checkForUpdates()
        } content: {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .disabled(!updater.canCheckForUpdates)
        .accessibilityLabel(title)
    }

    private func disabledProgressButton(
        title: String
    ) -> some View {
        DButton(style: .primary) {
        } content: {
            ProgressView()
                .controlSize(.small)

            Text(title)
                .frame(maxWidth: .infinity)
        }
        .disabled(true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("In progress")
    }

    private func statusText(_ message: String) -> some View {
        Text(message)
            .font(DawnTextStyle.primary)
            .foregroundStyle(DawnColors.secondaryForeground)
            .multilineTextAlignment(.center)
            .lineLimit(2)
    }

    @ViewBuilder
    private func releaseNotesControl(
        for update: AvailableAppUpdate
    ) -> some View {
        if let url =
            update.releaseNotesURL ?? update.informationURL
        {
            DButton(style: .linkSecondary) {
                NSWorkspace.shared.open(url)
            } content: {
                Text("What's new in \(update.displayVersion)")
            } trailing: {
                Image(systemName: "arrow.up.forward.square")
            }
            .accessibilityLabel(
                "What's new in version \(update.displayVersion)"
            )
            .accessibilityHint(
                "Opens the release notes in your browser"
            )
        } else {
            statusText(
                "Version \(update.displayVersion) is available."
            )
        }
    }

    @ViewBuilder
    private func updateProgress(
        _ progress: AppUpdateProgress,
        title: String
    ) -> some View {
        switch progress {
        case .indeterminate:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)

                Text(title)
                    .font(DawnTextStyle.primary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue("In progress")

        case .fraction(let fraction):
            let clampedFraction = min(max(fraction, 0), 1)
            let percentage = Int(
                (clampedFraction * 100).rounded()
            )

            VStack(spacing: 4) {
                ProgressView(
                    value: clampedFraction,
                    total: 1
                )
                .frame(maxWidth: 200)

                Text("\(percentage)%")
                    .font(DawnTextStyle.primary)
                    .foregroundStyle(
                        DawnColors.secondaryForeground
                    )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue("\(percentage) percent")
        }
    }

    private func unavailabilityMessage(
        for reason: AppUpdateUnavailabilityReason
    ) -> String {
        switch reason {
        case .currentVersionIsLatest:
            "Dawn is up to date."
        case .currentVersionIsNewer:
            "This build is newer than the latest release."
        case .systemIsTooOld:
            "The latest update requires a newer version of macOS."
        case .systemIsTooNew:
            "No update is available for this version of macOS."
        case .unsupportedHardware:
            "The latest update isn't compatible with this Mac."
        case .unknown:
            "No compatible update is currently available."
        }
    }

    private func failureMessage(
        for reason: AppUpdateFailureReason
    ) -> String {
        switch reason {
        case .updaterUnavailable:
            "Updates are temporarily unavailable."
        case .networkUnavailable:
            "Check your internet connection and try again."
        case .invalidFeed:
            "The update feed couldn't be loaded."
        case .invalidMetadata:
            "The available update information is invalid."
        case .invalidUpdate:
            "The downloaded update couldn't be verified."
        case .installationFailed:
            "The update couldn't be installed."
        case .componentPreparationFailed:
            "Dawn couldn't prepare its components for the update."
        case .componentRecoveryFailed:
            "DAWN couldn't restore its components after the update failed. Relaunch DAWN to retry."
        case .unknown:
            "The update couldn't be checked."
        }
    }
}
