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
    @Test("Workspace survives a Codable round trip")
    func workspaceCodableRoundTrip() throws {
        let application = WorkspaceApplication(
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            applicationURL: URL(
                fileURLWithPath: "/Applications/Safari.app"
            ),
            allowsRunningApplicationSubstitution: false,
            createsNewApplicationInstance: true,
            arguments: ["--args"],
            environment: ["FOO": "bar"],
            promptsUserIfNeeded: true,
            windowLayout: .minimized
        )

        let workspace = Workspace(
            name: "Study",
            symbol: "book",
            applications: [application],
            transition: WorkspaceTransition(
                activationPolicy: .merge,
                terminalCommand: "echo study"
            ),
            isArchived: true
        )

        let data = try JSONEncoder().encode(workspace)
        let decoded = try JSONDecoder().decode(
            Workspace.self,
            from: data
        )

        #expect(decoded == workspace)
    }

    @Test("Workspace defaults transition when decoding legacy payloads")
    func workspaceDefaultsMissingTransition() throws {
        let legacyJSON = Data("""
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Legacy",
            "symbol": "book",
            "applications": []
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(Workspace.self, from: legacyJSON)

        #expect(decoded.transition == .default)
        #expect(decoded.transition.activationPolicy == .hide)
        #expect(decoded.isArchived == false)
    }

    @Test("Create workspace event defaults transition when decoding legacy payloads")
    func createWorkspaceEventDefaultsMissingTransition() throws {
        let legacyJSON = Data("""
        {
            "name": "Legacy",
            "symbol": "book",
            "applications": []
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(
            CreateWorkspaceEvent.self,
            from: legacyJSON
        )

        #expect(decoded.transition == .default)
        #expect(decoded.transition.activationPolicy == .hide)
    }

    @Test("Workspace is active by default")
    func workspaceIsActiveByDefault() {
        let workspace = Workspace(name: "Study", symbol: "book")

        #expect(workspace.isArchived == false)
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
