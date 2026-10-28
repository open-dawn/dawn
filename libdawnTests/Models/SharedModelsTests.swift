//
//  SharedModelsTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 25/08/26.
//

import Foundation
import Testing
import libdawn

@Suite("Shared Models Tests")
struct SharedModelsTests {
    @Test("Workspace context survives a Codable round trip")
    func workspaceContextCodableRoundTrip() throws {
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
            applications: [application],
            transition: WorkspaceTransition(
                activationPolicy: .merge,
                terminalCommand: "echo study"
            )
        )

        let data = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(
            WorkspaceContext.self,
            from: data
        )

        #expect(decoded == context)
    }

    @Test("Workspace context defaults transition when decoding legacy payloads")
    func workspaceContextDefaultsMissingTransition() throws {
        let legacyJSON = Data("""
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Legacy",
            "symbol": "book",
            "applications": []
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(WorkspaceContext.self, from: legacyJSON)

        #expect(decoded.transition == .default)
        #expect(decoded.transition.activationPolicy == .hide)
    }

    @Test("General Settings survives a Codable round trip")
    func settingsCodableRoundTrip() throws {
        let app = ProtectedApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )
        let setting = Settings(
            launchAtLogin: true,
            showInMenuBar: false,
            forceAppsToQuit: true,
            analyticsEnabled: true,
            protectedApps: [app]
        )

        let data = try JSONEncoder().encode(setting)
        let decoded = try JSONDecoder().decode(
            Settings.self,
            from: data
        )

        #expect(decoded == setting)
    }

    @Test("General settings use expected defaults")
    func generalSettingsDefaultValue() {
        let settings = Settings()

        #expect(settings.launchAtLogin == false)
        #expect(settings.showInMenuBar)
        #expect(settings.forceAppsToQuit == false)
        #expect(settings.analyticsEnabled == false)
        #expect(settings.protectedApps.isEmpty)
    }
}
