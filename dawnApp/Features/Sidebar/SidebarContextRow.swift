// NEEDS REVIEW — PIN-132 (sidebar design): changed in this issue, pending organization review.
import libdawnUI
import SwiftUI

struct SidebarContextRow: View {
    private let name: String
    private let symbol: String
    private let state: SidebarRowState

    init(name: String, symbol: String, state: SidebarRowState) {
        self.name = name
        self.symbol = symbol
        self.state = state
    }

    var body: some View {
        HStack(spacing: 8) {
            icon

            Text(name)
                .font(DawnTextStyle.sidebarRow)
                .foregroundStyle(DawnColors.sidebarForeground)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            if state.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: SidebarMetrics.cornerRadius, style: .continuous)
                .fill(rowFill)
        }
        .opacity(state.isEnabled ? 1 : 0.4)
        .contentShape(
            RoundedRectangle(cornerRadius: SidebarMetrics.cornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .sidebarAccessibilityValue(accessibilityValue)
        .sidebarTruncationHelp(name)
    }

    private var icon: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: resolvedSymbol)
                .font(DawnTextStyle.sidebarIcon)
                .foregroundStyle(DawnColors.primaryForeground)
                .frame(width: SidebarMetrics.iconSize, height: SidebarMetrics.iconSize)

            if state.isActive {
                Circle()
                    .fill(DawnColors.sidebarActive)
                    .frame(
                        width: SidebarMetrics.activeBadgeSize,
                        height: SidebarMetrics.activeBadgeSize
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(Color.black, lineWidth: 1)
                    }
                    .offset(x: 2, y: 2)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: SidebarMetrics.iconSize, height: SidebarMetrics.iconSize)
        .accessibilityHidden(true)
    }

    private var resolvedSymbol: String {
        symbol.isEmpty ? "square.dashed" : symbol
    }

    private var rowFill: Color {
        SidebarChrome.fill(isSelected: state.isSelected)
    }

    private var accessibilityValue: String {
        if state.isLoading {
            return "Loading"
        }

        if state.isActive {
            return "Active"
        }

        if !state.isEnabled {
            return "Unavailable"
        }

        return ""
    }
}

private extension View {
    @ViewBuilder
    func sidebarAccessibilityValue(_ value: String) -> some View {
        if value.isEmpty {
            self
        } else {
            accessibilityValue(value)
        }
    }

    @ViewBuilder
    func sidebarTruncationHelp(_ name: String) -> some View {
        if name.count > SidebarMetrics.tooltipNameLength {
            help(name)
        } else {
            self
        }
    }
}
