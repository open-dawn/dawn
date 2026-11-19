import AppKit
import libdawnUI
import SwiftUI

enum SidebarMetrics {
    static let width: CGFloat = 280
    static let detailWidth: CGFloat = 680
    static let windowWidth: CGFloat = width + detailWidth
    static let windowHeight: CGFloat = 680

    static let minimumDetailWidth: CGFloat = detailWidth
    static let idealDetailWidth: CGFloat = detailWidth
    static let minimumWindowHeight: CGFloat = windowHeight

    static let horizontalPadding: CGFloat = 24
    static let titleBarPadding: CGFloat = 12
    static let sectionSpacing: CGFloat = 24
    static let listSpacing: CGFloat = 4
    static let footerSpacing: CGFloat = 8
    static let controlHeight: CGFloat = 28
    static let cornerRadius: CGFloat = 4
    static let rowCornerRadius: CGFloat = 4

    static let iconSize: CGFloat = 15
    static let iconTextSpacing: CGFloat = 8
    static let rowIconSize: CGFloat = 24
    static let activeBadgeSize: CGFloat = 10

    static let warningVerticalPadding: CGFloat = 8
    static let tooltipNameLength = 24

    static func fill(isSelected: Bool, isActive: Bool) -> Color {
        if isActive {
            return DawnColors.sidebarRowActive
        }

        if isSelected {
            return DawnColors.sidebarRowSelected
        }

        return .clear
    }
}

struct SidebarBackground: View {
    var body: some View {
        ZStack {
            SidebarVisualEffect()
            DawnColors.sidebarBackground
        }
    }
}

private struct SidebarVisualEffect: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .sidebar
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context _: Context) {
        nsView.blendingMode = .behindWindow
        nsView.material = .sidebar
        nsView.state = .active
    }
}
