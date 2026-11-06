import AppKit

protocol ApplicationProvider {
    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [any RunningApplicationControlling]
    func runningApplications() -> [any RunningApplicationControlling]
}

final class SystemApplicationProvider: ApplicationProvider {
    func runningApplications(withBundleIdentifier bundleID: String) -> [any RunningApplicationControlling] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    }

    func runningApplications() -> [any RunningApplicationControlling] {
        NSWorkspace.shared.runningApplications
    }
}
