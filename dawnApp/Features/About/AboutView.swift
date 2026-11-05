import AppKit
import libdawnUI
import SwiftUI

struct AboutView<Updater: AppUpdating>: View {
    let content: AboutContent
    let updater: Updater

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                DawnSymbol.image(height: 56)
                Text("dawn")
                    .font(.system(size: 32))
            }

            VStack(spacing: 4) {
                Text("Version \(content.appVersion)")
                    .font(DawnTextStyle.secondary)
                    .foregroundStyle(DawnColors.secondaryForeground)
                Text("\(content.ticket.commit.displayName)")
                    .font(DawnTextStyle.secondary)
                    .foregroundStyle(DawnColors.secondaryForeground)
                    .onTapGesture {
                        NSWorkspace.shared.open(content.ticket.commit.url)
                    }
            }

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("Dawn is designed by")
                        .font(DawnTextStyle.secondary)
                        .foregroundStyle(DawnColors.secondaryForeground)

                    DButton(style: .linkSecondary) {
                        NSWorkspace.shared.open(content.ticket.marketingURL)
                    } content: {
                        Text("OpenDawn")
                    }
                }

                HStack(spacing: 4) {
                    Text("and is open source, under the")
                        .font(DawnTextStyle.secondary)
                        .foregroundStyle(DawnColors.secondaryForeground)

                    DButton(style: .linkSecondary) {
                        NSWorkspace.shared.open(content.ticket.licenseURL)
                    } content: {
                        Text(verbatim: content.ticket.license)
                    }

                    Text("license.")
                        .font(DawnTextStyle.secondary)
                        .foregroundStyle(DawnColors.secondaryForeground)
                }
            }

            Spacer()

            HStack(alignment: .bottom, spacing: 16) {
                DButton(style: .secondary) {
                    NSWorkspace.shared.open(content.ticket.marketingURL)
                } content: {
                    Text("Give us Feedback")
                } leading: {
                    Image(systemName: "bubble.left.and.bubble.right")
                }

                updateControls
            }

            Text(content.ticket.copyright)
                .font(DawnTextStyle.secondary)
                .foregroundStyle(DawnColors.secondaryForeground)
        }
        .frame(minWidth: 512, maxWidth: .infinity)
        .padding(16)
        .background {
            DawnColors.primaryBackground
        }
    }
}

extension AboutView {
    @ViewBuilder
    private var updateControls: some View {
        switch updater.state {
        case .idle:
            updatePanel {
                Color.clear
                    .accessibilityHidden(true)
            } action: {
                checkButton(title: "Check for Updates")
            }

        case .checking:
            updatePanel {
                statusText("Looking for available updates...")
            } action: {
                disabledProgressButton(title: "Checking for Updates")
            }

        case .updateUnavailable(let reason):
            updatePanel {
                statusText(unavailabilityMessage(for: reason))
            } action: {
                checkButton(title: "Check Again")
            }

        case .updateAvailable(let update):
            updatePanel {
                releaseNotesControl(for: update)
            } action: {
                DButton(style: .primary) {
                    updater.installAvailableUpdate()
                } content: {
                    Text("Update Now")
                        .frame(minWidth: 200)
                }
                .accessibilityLabel("Update to version \(update.displayVersion)")
            }

        case .downloading(let update, let progress):
            updatePanel {
                statusText("Downloading version \(update.displayVersion)")
            } action: {
                updateProgress(progress, title: "Downloading Update")
            }

        case .extracting(let update, let progress):
            updatePanel {
                statusText(
                    "Preparing version \(update.displayVersion)..."
                )
            } action: {
                updateProgress(progress, title: "Preparing Update")
            }

        case .readyToInstall(let update):
            updatePanel {
                releaseNotesControl(for: update)
            } action: {
                DButton(style: .primary) {
                    updater.installAndRelaunch()
                } content: {
                    Text("Install and Relaunch")
                        .frame(minWidth: 200)
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
                checkButton(title: "Try Again")
            }

        }
    }

    private func updatePanel<Status: View, Action: View>(
        @ViewBuilder status: () -> Status,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(spacing: 4) {
            status()
                .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36)

            action()
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
        }
        .frame(width: 240, height: 84)
    }

    private func checkButton(title: String) -> some View {
        DButton(style: .secondary) {
            updater.checkForUpdates()
        } content: {
            Text(title)
                .frame(minWidth: 200)
        }
        .disabled(!updater.canCheckForUpdates)
        .accessibilityLabel(title)
    }

    private func disabledProgressButton(
        title: String
    ) -> some View {
        DButton(style: .secondary) {
        } content: {
            ProgressView()
                .controlSize(.small)

            Text(title)
                .frame(minWidth: 168)
        }
        .disabled(true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("In progress")
    }

    private func statusText(_ message: String) -> some View {
        Text(message)
            .font(DawnTextStyle.secondary)
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
            DButton(style: .link) {
                NSWorkspace.shared.open(url)
            } content: {
                Text("What's New in \(update.displayVersion)")
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
                    .font(DawnTextStyle.secondary)
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
                .frame(width: 200)

                Text("\(percentage)%")
                    .font(DawnTextStyle.secondary)
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
        case .unknown:
            "The update couldn't be checked."
        }
    }
}
