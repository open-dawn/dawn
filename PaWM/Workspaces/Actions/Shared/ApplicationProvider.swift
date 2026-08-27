import AppKit

protocol ApplicationProvider {
    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [NSRunningApplication]
}

class SystemApplicationProvider: ApplicationProvider {
    func runningApplications(withBundleIdentifier bundleID: String) -> [NSRunningApplication] {
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    }
}

final class FakeAppProvider: ApplicationProvider {
    var shouldFail: Bool = false
    func runningApplications(withBundleIdentifier _: String) -> [NSRunningApplication] {
        return shouldFail ? [] : [NSRunningApplication()]
    }
}
