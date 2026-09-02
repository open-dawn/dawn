import AppKit

public protocol ApplicationProvider {
    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [NSRunningApplication]
}

class SystemApplicationProvider: ApplicationProvider {
    func runningApplications(withBundleIdentifier bundleID: String) -> [NSRunningApplication] {
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    }
}