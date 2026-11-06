//
//  DawnAppOpener.swift
//  dawn
//
//  Created by Rafael Venetikides on 22/10/26.
//

import AppKit
import libdawn

@MainActor
protocol DawnAppOpening {
    func open(_ route: DawnAppRoute) async throws
}

@MainActor
struct DawnAppOpener: DawnAppOpening {
    private let workspace: any DawnAppWorkspaceOpening

    init(workspace: any DawnAppWorkspaceOpening = NSWorkspace.shared) {
        self.workspace = workspace
    }

    func open(_ route: DawnAppRoute) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        try await workspace.open(
            route.url,
            configuration: configuration
        )
    }
}

@MainActor
protocol DawnAppWorkspaceOpening {
    @discardableResult
    func open(_ url: URL, configuration: NSWorkspace.OpenConfiguration) async throws -> NSRunningApplication
}

extension NSWorkspace: DawnAppWorkspaceOpening {}
