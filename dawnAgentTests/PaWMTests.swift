import AppKit
import Testing
@testable import dawnAgent

@MainActor
@Test func appDelegateDoesNotTerminateWhenLastWindowCloses() {
    let delegate = dawnAgentAppDelegate()
    #expect(delegate.applicationShouldTerminateAfterLastWindowClosed(.shared) == false)
}
