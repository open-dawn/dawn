import AppKit
import Testing
@testable import PaWM

@MainActor
@Test func appDelegateDoesNotTerminateWhenLastWindowCloses() {
    let delegate = PaWMAppDelegate()
    #expect(delegate.applicationShouldTerminateAfterLastWindowClosed(.shared) == false)
}
