import libdawnUI
import SwiftUI

struct SidebarFooter: View {
    let content: SidebarContent
    let availableUpdate: AvailableAppUpdate?

    @Binding var selectedDestination: SidebarDestination?

    let onDismissError: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SidebarMetrics.footerSpacing) {
            errorNotice

            if !content.isAgentRunning {
                agentWarning
            } else if content.needsAccessibilityPermission {
                accessibilityError
            }

            updateButton

            #if DEBUG
                SidebarButton(
                    title: "Debug",
                    systemImage: "ladybug",
                    expands: true,
                    isSelected: selectedDestination == .debug,
                    action: { selectedDestination = .debug }
                )
            #endif

            HStack(alignment: .center, spacing: 8) {
                SidebarButton(
                    title: "Settings",
                    systemImage: "gearshape.fill",
                    isSelected: selectedDestination == .settings,
                    action: { selectedDestination = .settings }
                )

                Spacer(minLength: 0)

                SidebarButton(
                    title: "About",
                    systemImage: "info.circle.fill",
                    showsTitle: false,
                    isSelected: selectedDestination == .about,
                    action: { selectedDestination = .about }
                )
            }
        }
    }

    private var agentWarning: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(DawnTextStyle.sidebarBannerIcon)
                    .foregroundStyle(DawnColors.sidebarWarningForeground)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Dawn Agent is not running")
                        .font(DawnTextStyle.sidebarBannerTitle)
                        .foregroundStyle(DawnColors.sidebarForeground)
                        .lineLimit(2)

                    Text("Restart to start a new workspace")
                        .font(DawnTextStyle.sidebarBannerBody)
                        .foregroundStyle(DawnColors.sidebarForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: SidebarMetrics.cornerRadius, style: .continuous)
                .fill(DawnColors.sidebarBannerBackground)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dawn Agent is not running")
        .accessibilityValue("Workspaces stay unavailable until the agent starts.")
    }

    private var accessibilityError: some View {
        Button {
            selectedDestination = .settings
        } label: {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(DawnTextStyle.sidebarBannerIcon)
                    .foregroundStyle(DawnColors.sidebarErrorForeground)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Accessibility required")
                        .font(DawnTextStyle.sidebarBannerTitle)
                        .foregroundStyle(DawnColors.sidebarForeground)
                        .lineLimit(1)

                    // Text("Open Settings to grant Accessibility permission.")
                    //     .font(DawnTextStyle.sidebarBannerBody)
                    //     .foregroundStyle(DawnColors.sidebarForeground)
                    //     .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: SidebarMetrics.cornerRadius, style: .continuous)
                    .fill(DawnColors.sidebarBannerBackground)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Accessibility permission required")
        .accessibilityHint("Opens Settings to grant Accessibility permission")
    }

    @ViewBuilder
    private var updateButton: some View {
        if let update = availableUpdate {
            SidebarButton(
                title: "Update Now",
                systemImage: "arrow.down.circle",
                expands: true,
                action: { selectedDestination = .about },
                accessory: {
                    Text(update.displayVersion)
                        .font(DawnTextStyle.sidebarMeta)
                        .foregroundStyle(DawnColors.sidebarTertiaryForeground)
                        .lineLimit(1)
                }
            )
            .help("Update to version \(update.displayVersion)")
            .accessibilityLabel("Update available")
            .accessibilityValue("Version \(update.displayVersion)")
            .accessibilityHint("Opens About to review and install the update")
        }
    }

    @ViewBuilder
    private var errorNotice: some View {
        if !content.errorMessages.isEmpty {
            VStack(alignment: .leading, spacing: SidebarMetrics.footerSpacing) {
                ForEach(Array(content.errorMessages.enumerated()), id: \.element.id) { index, message in
                    errorBanner(message.text, isTopMost: index == 0)
                }
            }
        }
    }

    private func errorBanner(_ message: String, isTopMost: Bool) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DawnTextStyle.sidebarBannerIcon)
                .foregroundStyle(DawnColors.sidebarErrorForeground)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text("Error")
                        .font(DawnTextStyle.sidebarBannerTitle)
                        .foregroundStyle(DawnColors.sidebarForeground)

                    Spacer(minLength: 8)

                    if isTopMost {
                        Button(action: onDismissError) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(DawnColors.sidebarForeground)
                                .padding(4)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss error")
                    }
                }

                Text(message)
                    .font(DawnTextStyle.sidebarBannerBody)
                    .foregroundStyle(DawnColors.sidebarForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: SidebarMetrics.cornerRadius, style: .continuous)
                .fill(DawnColors.sidebarBannerBackground)
        }
        .accessibilityElement(children: isTopMost ? .contain : .ignore)
        .accessibilityLabel("Error")
        .accessibilityValue(message)
    }
}
