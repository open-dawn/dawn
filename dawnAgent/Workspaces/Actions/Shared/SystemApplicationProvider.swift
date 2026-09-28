import AppKit

protocol ApplicationProvider {
    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [any RunningApplicationControlling]
}

final class SystemApplicationProvider: ApplicationProvider {
    func runningApplications(withBundleIdentifier bundleID: String) -> [any RunningApplicationControlling] {
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    }
}
