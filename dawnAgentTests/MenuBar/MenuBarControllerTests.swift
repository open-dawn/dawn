//
//  MenuBarControllerTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 28/10/26.
//

import Testing
import AppKit

@testable import dawnAgent

@MainActor
@Suite("MenuBarController", .serialized)
struct MenuBarControllerTests {
    @Test("Visibility changes are idempotent")
    func visibilityChangesAreIdempotent() throws {
        let statusBar = StatusBarSpy()

        let runtime = WorkspaceRuntime(
            contextManager: FakeContextManager()
        )

        let sut = MenuBarController(
            workspace: runtime,
            initiallyVisible: false,
            statusBar: statusBar
        )

        defer {
            sut.stop()
            statusBar.cleanUp()
        }

        try #require(sut.isVisible == false)
        #expect(statusBar.creationCount == 0)

        sut.setVisible(true)
        sut.setVisible(true)

        #expect(sut.isVisible)
        #expect(statusBar.creationCount == 1)

        sut.setVisible(false)
        sut.setVisible(false)

        #expect(!sut.isVisible)
        #expect(statusBar.removalCount == 1)
    }

    @Test("Stopped controller cannot become visible again")
    func stoppedControllerCannotBecomeVisible() {
        let statusBar = StatusBarSpy()

        let runtime = WorkspaceRuntime(
            contextManager: FakeContextManager()
        )

        let sut = MenuBarController(
            workspace: runtime,
            initiallyVisible: true,
            statusBar: statusBar
        )

        defer {
            statusBar.cleanUp()
        }

        sut.stop()
        sut.setVisible(true)

        #expect(!sut.isVisible)
        #expect(statusBar.creationCount == 1)
        #expect(statusBar.removalCount == 1)
    }
}

@MainActor
private final class StatusBarSpy: StatusBarProviding {
    private let backingStatusBar = NSStatusBar.system
    private var createdItems: [NSStatusItem] = []

    private(set) var creationCount = 0
    private(set) var removalCount = 0

    func statusItem(
        withLength length: CGFloat
    ) -> NSStatusItem {
        creationCount += 1

        let item = backingStatusBar.statusItem(
            withLength: length
        )

        createdItems.append(item)
        return item
    }

    func removeStatusItem(_ item: NSStatusItem) {
        removalCount += 1
        backingStatusBar.removeStatusItem(item)

        createdItems.removeAll {
            $0 === item
        }
    }

    func cleanUp() {
        for item in createdItems {
            backingStatusBar.removeStatusItem(item)
        }

        createdItems.removeAll()
    }
}
