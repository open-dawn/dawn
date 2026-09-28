//
//  SharedModelsTests.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 25/08/26.
//

import Foundation
import Testing
import libdawn

@Suite("Shared Models Tests")
struct SharedModelsTests {
    @Test("Workspace context survives a Codable round trip")
    func workspaceContextCodableRoundTrip() async throws {
        let application = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            applicationURL: URL(
                fileURLWithPath: "/Applications/Safari.app"
            )
        )

        let context = WorkspaceContext(
            name: "Study",
            symbol: "book",
            applications: [application]
        )

        let data = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(
            WorkspaceContext.self,
            from: data
        )

        #expect(decoded == context)
    }

    @Test("General settings disable launch at login by default")
    func generalSettingsDefaultValue() async throws {
        let settings = GeneralSettings()

        #expect(settings.launchAtLogin == false)
    }
}
