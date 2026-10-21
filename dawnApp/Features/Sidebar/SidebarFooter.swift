import libdawnUI
import SwiftUI

struct SidebarFooter: View {
    let content: SidebarContent
    @Binding var selectedDestination: SidebarDestination?
    let onDismissError: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SidebarMetrics.footerSpacing) {
            if let errorMessage = content.errorMessage {
                SidebarErrorNotice(message: errorMessage, onDismiss: onDismissError)
            }

            if !content.isAgentRunning {
                SidebarAgentWarning()
            }

            if let update = content.update {
                SidebarUpdateLink(update: update)
            }

            HStack(alignment: .center, spacing: 8) {
                SidebarFooterButton(
                    title: "Settings",
                    systemImage: "gearshape",
                    showsTitle: true,
                    isSelected: selectedDestination == .settings,
                    action: { selectedDestination = .settings }
                )

                Spacer(minLength: 0)

                SidebarFooterButton(
                    title: "About",
                    systemImage: "info.circle",
                    showsTitle: false,
                    isSelected: selectedDestination == .about,
                    action: { selectedDestination = .about }
                )
            }
        }
    }
}

private struct SidebarAgentWarning: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DawnTextStyle.sidebarIcon)
                .accessibilityHidden(true)

            Text("The DAWN Agent is not running")
                .font(DawnTextStyle.sidebarWarning)
                .lineLimit(1)
        }
        .foregroundStyle(DawnColors.sidebarWarningForeground)
        .frame(maxWidth: .infinity)
        .padding(.vertical, SidebarMetrics.warningVerticalPadding)
        .background {
            RoundedRectangle(cornerRadius: SidebarMetrics.cornerRadius, style: .continuous)
                .fill(DawnColors.sidebarWarningBackground)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The DAWN Agent is not running")
    }
}

private struct SidebarUpdateLink: View {
    let update: AppUpdateAvailability

    var body: some View {
        Link(destination: update.releaseURL) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle")
                    .font(DawnTextStyle.sidebarIcon)
                    .frame(width: SidebarMetrics.iconSize, height: SidebarMetrics.iconSize)

                Text("Update Now")
                    .font(DawnTextStyle.sidebarFooter)
                    .lineLimit(1)

                Text(update.version)
                    .font(DawnTextStyle.sidebarMeta)
                    .foregroundStyle(DawnColors.sidebarTertiaryForeground)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(DawnColors.sidebarForeground)
            .padding(.horizontal, 8)
            .frame(minHeight: SidebarMetrics.controlHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Update to version \(update.version)")
        .accessibilityLabel("Update Now")
        .accessibilityValue("Version \(update.version)")
        .accessibilityHint("Opens the release page in the browser")
    }
}

private struct SidebarFooterButton: View {
    let title: String
    let systemImage: String
    let showsTitle: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(DawnTextStyle.sidebarIcon)
                    .frame(width: SidebarMetrics.iconSize, height: SidebarMetrics.iconSize)

                if showsTitle {
                    Text(title)
                        .font(DawnTextStyle.sidebarFooter)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(DawnColors.sidebarForeground)
            .padding(.horizontal, 8)
            .frame(minHeight: SidebarMetrics.controlHeight)
            .background {
                RoundedRectangle(cornerRadius: SidebarMetrics.cornerRadius, style: .continuous)
                    .fill(SidebarChrome.fill(isSelected: isSelected))
            }
            .contentShape(
                RoundedRectangle(cornerRadius: SidebarMetrics.cornerRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : AccessibilityTraits())
    }
}

private struct SidebarErrorNotice: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DawnTextStyle.sidebarIcon)
                .accessibilityHidden(true)

            Text(message)
                .font(DawnTextStyle.sidebarWarning)
                .lineLimit(3)
        }
        .foregroundStyle(DawnColors.dangerForeground)
        .frame(maxWidth: .infinity)
        .padding(.vertical, SidebarMetrics.warningVerticalPadding)
        .background {
            RoundedRectangle(cornerRadius: SidebarMetrics.cornerRadius, style: .continuous)
                .fill(DawnColors.dangerForeground.opacity(0.15))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
        .onTapGesture {
            onDismiss()
        }
    }
}
