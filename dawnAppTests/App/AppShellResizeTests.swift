// NEEDS REVIEW — PIN-132 (sidebar design): changed in this issue, pending organization review.
@testable import dawnApp
import AppKit
import libdawn
import SwiftUI
import Testing

@MainActor
@Suite("App shell resize")
struct AppShellResizeTests {
    @Test("Split view follows the window when it grows and shrinks")
    func splitViewFollowsWindowResize() throws {
        let store = SettingsContextStore(bus: ContextEventBusFake())
        let service = SettingsEventBusService()

        let view = AppShellView()
            .environment(service)
            .environment(store)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 680),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: view)
        window.layoutIfNeeded()
        pump(window)

        let contentView = try #require(window.contentView)
        let split = try #require(findSplit(in: contentView))
        let initialPanes = try #require(panes(in: split))

        // Initial size: the split fills the window, sidebar is fixed,
        // the detail pane takes the rest.
        #expect(abs(split.frame.width - contentView.frame.width) < 2)
        #expect(abs(initialPanes.sidebar.width - SidebarMetrics.width) < 2)
        let initialDetailWidth = initialPanes.detail.width
        #expect(initialDetailWidth > initialPanes.sidebar.width)

        // Growing the window grows the split and the detail pane;
        // nothing stays frozen at the original size.
        window.setContentSize(NSSize(width: 1400, height: 800))
        window.layoutIfNeeded()
        pump(window)

        let grownPanes = try #require(panes(in: split))
        #expect(abs(split.frame.width - 1400) < 2)
        #expect(abs(grownPanes.sidebar.width - SidebarMetrics.width) < 2)
        #expect(grownPanes.detail.width > initialDetailWidth + 300)

        // Shrinking the window shrinks the split with it instead of
        // clipping a frozen view.
        window.setContentSize(NSSize(width: 820, height: 600))
        window.layoutIfNeeded()
        pump(window)

        let shrunkPanes = try #require(panes(in: split))
        #expect(abs(split.frame.width - 820) < 2)
        #expect(abs(shrunkPanes.sidebar.width - SidebarMetrics.width) < 2)
        #expect(shrunkPanes.detail.width < grownPanes.detail.width)
        #expect(shrunkPanes.detail.width >= SidebarMetrics.minimumDetailWidth - 2)
    }

    private func pump(_ window: NSWindow) {
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        window.layoutIfNeeded()
        window.contentView?.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    private func panes(in split: NSSplitView) -> (sidebar: NSRect, detail: NSRect)? {
        let subviews = split.arrangedSubviews
        guard subviews.count == 2 else {
            return nil
        }
        return (subviews[0].frame, subviews[1].frame)
    }

    private func findSplit(in view: NSView) -> NSSplitView? {
        if let split = view as? NSSplitView {
            return split
        }
        for subview in view.subviews {
            if let split = findSplit(in: subview) {
                return split
            }
        }
        return nil
    }
}

@MainActor
private final class ContextEventBusFake: SettingsContextEventBus {
    func addListener(_ listener: Listener, kinds: Set<EventKind>?) {}

    func removeListener(_ listener: Listener) {}

    func ask(_ event: Event, timeout: Duration) async throws -> Event {
        throw CancellationError()
    }
}
