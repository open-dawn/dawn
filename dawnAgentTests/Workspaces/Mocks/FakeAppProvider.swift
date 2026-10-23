import AppKit
@testable import dawnAgent

final class FakeAppProvider: ApplicationProvider {
    var appsByBundleIdentifier: [String: [any RunningApplicationControlling]] = [:]
    var allApps: [any RunningApplicationControlling] = []

    func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [any RunningApplicationControlling] {
        appsByBundleIdentifier[bundleIdentifier] ?? []
    }

    func runningApplications() -> [any RunningApplicationControlling] {
        allApps
    }
}
