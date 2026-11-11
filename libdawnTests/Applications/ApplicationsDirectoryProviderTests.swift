import Foundation
import Testing
import libdawn

@Suite("Applications Directory Provider")
struct ApplicationsDirectoryProviderTests {
    @Test("A symlinked application is included and a directory symlink is not followed")
    func includesSymlinkedApplication() async throws {
        let fixture = try ApplicationScanFixture()
        defer { fixture.remove() }

        let outside = fixture.root.appendingPathComponent("Outside", isDirectory: true)
        try fixture.makeApplication(
            named: "Safari",
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            in: outside
        )
        try FileManager.default.createSymbolicLink(
            at: fixture.applications.appendingPathComponent("Safari.app"),
            withDestinationURL: outside.appendingPathComponent("Safari.app")
        )
        try fixture.makeApplication(
            named: "Notes",
            bundleIdentifier: "com.apple.Notes",
            displayName: "Notes",
            in: fixture.applications.appendingPathComponent("Tools", isDirectory: true)
        )
        try FileManager.default.createSymbolicLink(
            at: fixture.applications.appendingPathComponent("Loop"),
            withDestinationURL: fixture.applications
        )

        let found = try await ApplicationsDirectoryProvider(
            directories: [fixture.applications]
        ).applications()

        #expect(found.map(\.bundleIdentifier).sorted() == [
            "com.apple.Notes",
            "com.apple.Safari",
        ])

        let safari = try #require(found.first {
            $0.bundleIdentifier == "com.apple.Safari"
        })
        #expect(safari.displayName == "Safari")
        #expect(
            safari.applicationURL?.standardizedFileURL.path
                == fixture.applications
                .appendingPathComponent("Safari.app")
                .standardizedFileURL.path
        )
    }

    @Test("An application with the hidden flag is included")
    func includesHiddenFlaggedApplication() async throws {
        let fixture = try ApplicationScanFixture()
        defer { fixture.remove() }

        try fixture.makeApplication(
            named: "Safari",
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            in: fixture.applications
        )
        var safariURL = fixture.applications.appendingPathComponent("Safari.app")
        var values = URLResourceValues()
        values.isHidden = true
        try safariURL.setResourceValues(values)

        let found = try await ApplicationsDirectoryProvider(
            directories: [fixture.applications]
        ).applications()

        #expect(found.map(\.bundleIdentifier) == ["com.apple.Safari"])
    }

    @Test("Hidden applications are skipped")
    func skipsHiddenApplications() async throws {
        let fixture = try ApplicationScanFixture()
        defer { fixture.remove() }

        try fixture.makeApplication(
            named: ".Secret",
            bundleIdentifier: "com.example.secret",
            displayName: "Secret",
            in: fixture.applications
        )
        try fixture.makeApplication(
            named: "Mail",
            bundleIdentifier: "com.apple.mail",
            displayName: "Mail",
            in: fixture.applications
        )

        let found = try await ApplicationsDirectoryProvider(
            directories: [fixture.applications]
        ).applications()

        #expect(found.map(\.bundleIdentifier) == ["com.apple.mail"])
    }
}

private struct ApplicationScanFixture {
    let root: URL
    let applications: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dawn-app-scan-\(UUID().uuidString)", isDirectory: true)
        applications = root.appendingPathComponent("Applications", isDirectory: true)
        try FileManager.default.createDirectory(
            at: applications,
            withIntermediateDirectories: true
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    func makeApplication(
        named name: String,
        bundleIdentifier: String,
        displayName: String,
        in directory: URL
    ) throws {
        let contents = directory
            .appendingPathComponent("\(name).app", isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(
            at: contents,
            withIntermediateDirectories: true
        )

        let info = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": name,
            "CFBundleDisplayName": displayName,
            "CFBundlePackageType": "APPL",
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try data.write(to: contents.appendingPathComponent("Info.plist"))
    }
}
