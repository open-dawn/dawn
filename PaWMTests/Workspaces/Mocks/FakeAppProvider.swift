import AppKit
@testable import PaWM

final class FakeAppProvider: ApplicationProvider {
    var shouldFail: Bool = false
    func runningApplications(withBundleIdentifier _: String) -> [NSRunningApplication] {
        return shouldFail ? [] : [NSRunningApplication()]
    }
}