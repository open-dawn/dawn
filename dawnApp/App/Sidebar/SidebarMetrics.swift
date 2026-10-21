import AppKit
import libdawnUI
import SwiftUI

enum SidebarMetrics {
    static let minimumWidth: CGFloat = 230
    static let idealWidth: CGFloat = 252
    static let maximumWidth: CGFloat = 300
    static let minimumDetailWidth: CGFloat = 520
    static let idealDetailWidth: CGFloat = 760
    static let minimumWindowHeight: CGFloat = 560

    static let horizontalPadding: CGFloat = 12
    static let sectionSpacing: CGFloat = 14
    static let footerSpacing: CGFloat = 8
    static let controlHeight: CGFloat = 28
    static let cornerRadius: CGFloat = 8

    static let iconSize: CGFloat = 24
    static let activeBadgeSize: CGFloat = 10

    static let trafficLightClearance: CGFloat = 72
    static let headerHeight: CGFloat = 24
    static let headerTopPadding: CGFloat = 9
    static let headerSpacing: CGFloat = 18
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
