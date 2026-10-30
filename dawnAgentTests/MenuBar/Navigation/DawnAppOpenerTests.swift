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
    @Test("opens the encoded route and activates DAWN")
    func opensRoute() async throws {
        let contextID = UUID()
        let route = DawnAppRoute.context(contextID)
        let workspace = DawnAppWorkspaceSpy()
        let opener = DawnAppOpener(workspace: workspace)

        try await opener.open(route)

        #expect(workspace.openedURL == route.url)
        #expect(workspace.activatesApplication)
    }

    @Test("propagates workspace opening failures")
    func propagatesFailure() async {
        let workspace = DawnAppWorkspaceSpy()
        workspace.error = ExpectedError.openFailed

        let opener = DawnAppOpener(workspace: workspace)

        await #expect(throws: ExpectedError.openFailed) {
            try await opener.open(.settings)
        }
    }
}

@MainActor
private final class DawnAppWorkspaceSpy: DawnAppWorkspaceOpening {
    private(set) var openedURL: URL?
    private(set) var activatesApplication = false

    var error: Error?

    func open(_ url: URL, configuration: NSWorkspace.OpenConfiguration) async throws -> NSRunningApplication {
        openedURL = url
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
