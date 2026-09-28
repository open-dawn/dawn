import AppKit
import Testing
@testable import dawnAgent

@MainActor
@Test func appDelegateDoesNotTerminateWhenLastWindowCloses() {
    let delegate = AppDelegate()
    #expect(delegate.applicationShouldTerminateAfterLastWindowClosed(.shared) == false)
}
