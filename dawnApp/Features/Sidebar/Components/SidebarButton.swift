import libdawnUI
import SwiftUI

struct SidebarButton<Accessory: View>: View {
    let title: String
    let systemImage: String
    var showsTitle = true
    var expands = false
    var isSelected = false
    let action: () -> Void
    private let accessory: Accessory

    init(
        title: String,
        systemImage: String,
        showsTitle: Bool = true,
        expands: Bool = false,
        isSelected: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.systemImage = systemImage
        self.showsTitle = showsTitle
        self.expands = expands
        self.isSelected = isSelected
        self.action = action
        self.accessory = accessory()
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: SidebarMetrics.iconTextSpacing) {
                Image(systemName: systemImage)
                    .font(DawnTextStyle.sidebarIcon)
                    .foregroundStyle(DawnColors.sidebarIcon)
                    .frame(width: SidebarMetrics.iconSize, height: SidebarMetrics.iconSize)

                if showsTitle {
                    Text(title)
                        .font(DawnTextStyle.sidebarAction)
                        .foregroundStyle(DawnColors.sidebarForeground)
                        .lineLimit(1)
                }

                if expands {
                    Spacer(minLength: 0)
                }

                accessory
            }
            .frame(minHeight: SidebarMetrics.controlHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : AccessibilityTraits())
    }
}

extension SidebarButton where Accessory == EmptyView {
    init(
        title: String,
        systemImage: String,
        showsTitle: Bool = true,
        expands: Bool = false,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            showsTitle: showsTitle,
            expands: expands,
            isSelected: isSelected,
            action: action,
            accessory: { EmptyView() }
        )
    }
}
