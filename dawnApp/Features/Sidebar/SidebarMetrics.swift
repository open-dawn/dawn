// NEEDS REVIEW — PIN-132 (sidebar design): changed in this issue, pending organization review.
import AppKit
import libdawnUI
import SwiftUI

enum SidebarMetrics {
    // Sidebar and details sizes
    static let width: CGFloat = 260
    static let minimumDetailWidth: CGFloat = 520
    static let idealDetailWidth: CGFloat = 760

    static let minimumWindowHeight: CGFloat = 560

    // Inner paddings
    static let horizontalPadding: CGFloat = 12
    static let sectionSpacing: CGFloat = 14
    static let footerSpacing: CGFloat = 8
    static let controlHeight: CGFloat = 28
    static let cornerRadius: CGFloat = 8

    // Context icon
    static let iconSize: CGFloat = 24
    static let activeBadgeSize: CGFloat = 10

    // Others
    static let warningVerticalPadding: CGFloat = 10
    static let tooltipNameLength = 24
}

enum SidebarChrome {
    static func fill(isSelected: Bool) -> Color {
        isSelected ? DawnColors.sidebarRowSelected : .clear
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
