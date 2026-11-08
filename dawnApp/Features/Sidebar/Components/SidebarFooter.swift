import libdawnUI
import SwiftUI

struct SidebarFooter: View {
    let content: SidebarContent
    let availableUpdate: AvailableAppUpdate?

    @Binding var selectedDestination: SidebarDestination?

    let onDismissError: () -> Void
    let onRestartAgent: () -> Void

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
            footerButton(
                title: "Debug",
                systemImage: "ladybug",
                showsTitle: true,
                isSelected: selectedDestination == .debug,
                action: { selectedDestination = .debug }
            )
            #endif

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
        VStack(spacing: 8) {
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

            DButton(style: .warning, action: onRestartAgent) {
                Text("Restart")
                    .frame(maxWidth: .infinity)
                    .font(.caption2)
            }
            .accessibilityLabel("Restart DAWN Agent")
        }
        .padding(.vertical, SidebarMetrics.warningVerticalPadding)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: SidebarMetrics.cornerRadius, style: .continuous)
                .fill(DawnColors.sidebarWarningBackground)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("The DAWN Agent is not running")
    }

    private var accessibilityError: some View {
        Button {
            selectedDestination = .settings
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(DawnTextStyle.sidebarIcon)
                    .accessibilityHidden(true)

                Text("Accessibility permission required")
                    .font(DawnTextStyle.sidebarWarning)
                    .lineLimit(2)
            }
            .foregroundStyle(DawnColors.dangerForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SidebarMetrics.warningVerticalPadding)
            .background {
                RoundedRectangle(cornerRadius: SidebarMetrics.cornerRadius, style: .continuous)
                    .fill(DawnColors.dangerForeground.opacity(0.15))
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
            Button {
                selectedDestination = .about
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle")
                        .font(DawnTextStyle.sidebarIcon)
                        .frame(width: SidebarMetrics.iconSize, height: SidebarMetrics.iconSize)
                        .accessibilityHidden(true)

                    Text("Update Now")
                        .font(DawnTextStyle.sidebarFooter)
                        .lineLimit(1)

                    Text(update.displayVersion)
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
            .accessibilityLabel("Update available")
            .help("Update to version \(update.displayVersion)")
            .accessibilityValue("Version \(update.displayVersion)")
            .accessibilityHint("Opens About to review and install the update")
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
        if !content.errorMessages.isEmpty {
            VStack(alignment: .leading, spacing: SidebarMetrics.footerSpacing) {
                ForEach(Array(content.errorMessages.enumerated()), id: \.element.id) { index, message in
                    errorBanner(message.text, isTopMost: index == 0)
                }
            }
        }
    }

    private func errorBanner(_ message: String, isTopMost: Bool) -> some View {
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
            guard isTopMost else {
                return
            }

            onDismissError()
        }
        .onTapGesture {
            guard isTopMost else {
                return
            }

            onDismissError()
        }
    }
}
