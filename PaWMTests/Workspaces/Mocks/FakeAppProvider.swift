import AppKit
@testable import PaWM

final class FakeAppProvider: ApplicationProvider {
    var apps: [any RunningApplicationControlling] = [NSRunningApplication()]
    func runningApplications(withBundleIdentifier _: String) -> [any RunningApplicationControlling] {
        return apps
    }
}
