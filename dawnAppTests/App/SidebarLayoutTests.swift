@testable import dawnApp
import AppKit
import libdawn
import libdawnUI
import SwiftUI
import Testing

@MainActor
@Suite("Sidebar layout")
struct SidebarLayoutTests {
    @Test("DawnLogo wordmark stays compact")
    func logoStaysCompact() {
        let hosting = NSHostingView(rootView: DawnLogo(variant: .wordmark))
        hosting.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        hosting.layoutSubtreeIfNeeded()

        #expect(hosting.fittingSize.width < 140)
        #expect(hosting.fittingSize.height < 40)
    }

    @Test("Sidebar renders contexts in a scroll view with no native list selection")
    func sidebarRendersContexts() throws {
        let academy = WorkspaceContext(name: "Apple Developer Academy", symbol: "apple.logo")
        let gaming = WorkspaceContext(name: "Gaming", symbol: "gamecontroller.fill")
        let content = SidebarContent(
            contexts: [academy, gaming],
            activeContextID: academy.id
        )

        let view = SidebarView(
            content: content,
            selectedDestination: .constant(.context(academy.id)),
            onCreateContext: {}
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 252, height: 640),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: view)
        window.contentView?.frame = NSRect(x: 0, y: 0, width: 252, height: 640)
        window.layoutIfNeeded()
        window.contentView?.layoutSubtreeIfNeeded()

        RunLoop.main.run(until: Date().addingTimeInterval(1.0))
        window.contentView?.layoutSubtreeIfNeeded()

        let contentView = try #require(window.contentView)

        // No NSTableView anywhere: nothing can draw the native
        // accent-colored selection highlight over a selected row.
        #expect(findTable(in: contentView) == nil)

        let scroll = try #require(findScroll(in: contentView))
        #expect(scroll.frame.height > 200)

        // The context header, two context rows and the archived header
        // are laid out inside the scroll view.
        let documentHeight = scroll.documentView?.frame.height ?? 0
        #expect(documentHeight > 100)
    }

    private func findTable(in view: NSView) -> NSTableView? {
        if let table = view as? NSTableView {
            return table
        }
        for subview in view.subviews {
            if let table = findTable(in: subview) {
                return table
            }
        }
        return nil
    }

    private func findScroll(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView {
            return scroll
        }
        for subview in view.subviews {
            if let scroll = findScroll(in: subview) {
                return scroll
            }
        }
        return nil
    }

}
