//
//  DawnAppOpenerTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 22/10/26.
//

import AppKit
import Foundation
import Testing
import libdawn

@testable import dawnAgent

@MainActor
@Suite("DAWN app opener")
struct DawnAppOpenerTests {
    @Test("opens the encoded route in the located host app")
    func opensRouteInHostApp() async throws {
        let contextID = UUID()
        let route = DawnAppRoute.context(contextID)
        let hostAppURL = URL(filePath: "/Applications/DAWN.app")
        let workspace = DawnAppWorkspaceSpy()
        let opener = DawnAppOpener(workspace: workspace, hostAppURL: { hostAppURL })

        try await opener.open(route)

        #expect(workspace.openedURL == route.url)
        #expect(workspace.applicationURL == hostAppURL)
        #expect(workspace.activatesApplication)
    }

    @Test("propagates workspace opening failures")
    func propagatesFailure() async {
        let workspace = DawnAppWorkspaceSpy()
        workspace.error = ExpectedError.openFailed

        let opener = DawnAppOpener(
            workspace: workspace,
            hostAppURL: { URL(filePath: "/Applications/DAWN.app") }
        )

        await #expect(throws: ExpectedError.openFailed) {
            try await opener.open(.settings)
        }
    }

    @Test("fails when the host app cannot be located")
    func failsWhenHostAppIsMissing() async {
        let opener = DawnAppOpener(
            workspace: DawnAppWorkspaceSpy(),
            hostAppURL: { nil }
        )

        await #expect(throws: DawnAppOpenError.hostAppNotFound) {
            try await opener.open(.application)
        }
    }
}

@Suite("DAWN app host locator")
struct DawnAppHostLocatorTests {
    @Test("resolves the embedding DAWN.app from a LoginItems agent")
    func resolvesEmbeddedHost() {
        let agentURL = URL(
            fileURLWithPath: "/Applications/DAWN.app/Contents/Library/LoginItems/dawnAgent.app"
        )

        let hostPath = DawnAppHostLocator.embeddedHostAppURL(from: agentURL)?
            .standardizedFileURL
            .path(percentEncoded: false)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        #expect(hostPath == "Applications/DAWN.app")
    }

    @Test("ignores a standalone agent that is not under LoginItems")
    func ignoresStandaloneAgent() {
        let agentURL = URL(
            filePath: "/Users/me/DerivedData/Build/Products/Debug/dawnAgent.app"
        )

        #expect(DawnAppHostLocator.embeddedHostAppURL(from: agentURL) == nil)
    }

    @Test("falls back to the registered DAWN bundle when not embedded")
    func fallsBackToRegisteredBundle() {
        let registered = URL(filePath: "/Applications/DAWN.app")

        let resolved = DawnAppHostLocator.hostAppURL(
            agentBundleURL: URL(
                filePath: "/Users/me/DerivedData/Build/Products/Debug/dawnAgent.app"
            ),
            urlForApplication: { bundleIdentifier in
                #expect(bundleIdentifier == DawnAppHostLocator.appBundleIdentifier)
                return registered
            }
        )

        #expect(resolved == registered)
    }
}

@MainActor
private final class DawnAppWorkspaceSpy: DawnAppWorkspaceOpening {
    private(set) var openedURL: URL?
    private(set) var applicationURL: URL?
    private(set) var activatesApplication = false

    var error: Error?

    func open(
        _ url: URL,
        withApplicationAt applicationURL: URL,
        configuration: NSWorkspace.OpenConfiguration
    ) async throws -> NSRunningApplication {
        openedURL = url
        self.applicationURL = applicationURL
        activatesApplication = configuration.activates

        if let error {
            throw error
        }

        return NSRunningApplication()
    }
}

private enum ExpectedError: Error {
    case openFailed
}
