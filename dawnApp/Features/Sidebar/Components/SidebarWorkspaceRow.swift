import libdawnUI
import SwiftUI

struct SidebarWorkspaceRow: View {
    private let name: String
    private let symbol: String
    private let state: SidebarRowState

    init(name: String, symbol: String, state: SidebarRowState) {
        self.name = name
        self.symbol = symbol
        self.state = state
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            icon

            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(DawnTextStyle.sidebarRow)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: DawnTextStyle.metaSize, weight: .semibold))
                        .padding(.bottom, 1)

                    Text(state.activityText)
                        .font(DawnTextStyle.sidebarSectionHeader)
                        .dawnZainOpticalAlignment()
                        .lineLimit(1)
                }
                .foregroundStyle(metaColor)
            }

            Spacer(minLength: 0)

            if state.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            }
        }
        .padding(8)
        .padding(.top, 2)
        .background {
            RoundedRectangle(cornerRadius: SidebarMetrics.rowCornerRadius, style: .continuous)
                .fill(rowFill)
        }
        .opacity(state.isEnabled ? 1 : 0.4)
        .contentShape(
            RoundedRectangle(cornerRadius: SidebarMetrics.rowCornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityValue(accessibilityValue)
        .sidebarTruncationHelp(name)
    }

    private var icon: some View {
        Image(systemName: resolvedSymbol)
            .font(DawnTextStyle.sidebarRowIcon)
            .foregroundStyle(titleColor)
            .frame(width: SidebarMetrics.rowIconSize, height: SidebarMetrics.rowIconSize)
            .contentTransition(.symbolEffect)
            .accessibilityHidden(true)
    }

    private var resolvedSymbol: String {
        symbol.isEmpty ? "square.dashed" : symbol
    }

    private var rowFill: Color {
        SidebarMetrics.fill(isSelected: state.isSelected, isActive: state.isActive)
    }

    private var titleColor: Color {
        if state.isActive {
            return DawnColors.sidebarActiveForeground
        }

        if state.isSelected {
            return DawnColors.sidebarSelectedForeground
        }

        return DawnColors.sidebarForeground
    }

    private var metaColor: Color {
        if state.isActive {
            return DawnColors.sidebarActiveMeta
        }

        if state.isSelected {
            return DawnColors.sidebarSelectedMeta
        }

        return DawnColors.sidebarMeta
    }

    private var accessibilityValue: String {
        var parts: [String] = [state.activityText]

        if state.isLoading {
            parts.append("Loading")
        }

        if state.isActive {
            parts.append("Active")
        }

        if !state.isEnabled {
            parts.append("Unavailable")
        }

        return parts.joined(separator: ", ")
    }
}

private extension View {
    @ViewBuilder
    func sidebarTruncationHelp(_ name: String) -> some View {
        if name.count > SidebarMetrics.tooltipNameLength {
            help(name)
        } else {
            self
        }
    }
}
