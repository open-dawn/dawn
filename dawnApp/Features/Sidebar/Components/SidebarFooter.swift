import libdawnUI
import SwiftUI

struct SidebarFooter: View {
    let content: SidebarContent
    @Binding var selectedDestination: SidebarDestination?
    let onDismissError: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SidebarMetrics.footerSpacing) {
            errorNotice

            if !content.isAgentRunning {
                agentWarning
            }

            updateLink

            HStack(alignment: .center, spacing: 8) {
                footerButton(
                    title: "Settings",
                    systemImage: "gearshape",
                    showsTitle: true,
                    isSelected: selectedDestination == .settings,
                    action: { selectedDestination = .settings }
                )

                Spacer(minLength: 0)

                footerButton(
                    title: "About",
                    systemImage: "info.circle",
                    showsTitle: false,
                    isSelected: selectedDestination == .about,
                    action: { selectedDestination = .about }
                )
            }
        }
    }

    private var agentWarning: some View {
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

    @ViewBuilder
    private var updateLink: some View {
        if let update = content.update {
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
            .accessibilityValue("Version \(update.version)")
            .accessibilityHint("Opens the release page in the browser")
        }
    }

    private func footerButton(
        title: String,
        systemImage: String,
        showsTitle: Bool,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
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
                    .fill(SidebarMetrics.fill(isSelected: isSelected))
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

    @ViewBuilder
    private var errorNotice: some View {
        if let message = content.errorMessage {
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
            .accessibilityAction {
                onDismissError()
            }
            .onTapGesture {
                onDismissError()
            }
        }
    }
}
