//
//  DawnAppOpener.swift
//  dawn
//
//  Created by Rafael Venetikides on 22/10/26.
//

import AppKit
import dawnLogging
import libdawn

@MainActor
protocol DawnAppOpening {
    func open(_ route: DawnAppRoute) async throws
}

@MainActor
struct DawnAppOpener: DawnAppOpening {
    private let workspace: any DawnAppWorkspaceOpening
    private let hostAppURL: () -> URL?

    init(
        workspace: any DawnAppWorkspaceOpening = NSWorkspace.shared,
        hostAppURL: @escaping () -> URL? = { DawnAppHostLocator.hostAppURL() }
    ) {
        self.workspace = workspace
        self.hostAppURL = hostAppURL
    }

    func open(_ route: DawnAppRoute) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        guard let applicationURL = hostAppURL() else {
            #log(
                "Could not locate DAWN.app to open \(route.url.absoluteString, privacy: .public)",
                level: .error,
                category: .appLifecycle
            )
            throw DawnAppOpenError.hostAppNotFound
        }

        try await workspace.open(
            route.url,
            withApplicationAt: applicationURL,
            configuration: configuration
        )
    }
}

enum DawnAppOpenError: Error {
    case hostAppNotFound
}

enum DawnAppHostLocator {
    static let appBundleIdentifier = "app.opendawn.dawnApp"

    /// Prefer the DAWN.app that embeds this login item so a DerivedData agent
    /// does not open an older copy registered for the `opendawn` URL scheme.
    static func hostAppURL(
        agentBundleURL: URL = Bundle.main.bundleURL,
        urlForApplication: (String) -> URL? = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        }
    ) -> URL? {
        if let embeddedHost = embeddedHostAppURL(from: agentBundleURL) {
            return embeddedHost
        }

        return urlForApplication(appBundleIdentifier)
    }

    static func embeddedHostAppURL(from agentBundleURL: URL) -> URL? {
        let loginItemsDirectory = agentBundleURL.deletingLastPathComponent()
        guard loginItemsDirectory.lastPathComponent == "LoginItems" else {
            return nil
        }

        let hostAppURL = loginItemsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        guard hostAppURL.pathExtension == "app" else {
            return nil
        }

        return hostAppURL
    }
}

@MainActor
protocol DawnAppWorkspaceOpening {
    @discardableResult
    func open(
        _ url: URL,
        withApplicationAt applicationURL: URL,
        configuration: NSWorkspace.OpenConfiguration
    ) async throws -> NSRunningApplication
}

extension NSWorkspace: DawnAppWorkspaceOpening {
    func open(
        _ url: URL,
        withApplicationAt applicationURL: URL,
        configuration: NSWorkspace.OpenConfiguration
    ) async throws -> NSRunningApplication {
        try await open(
            [url],
            withApplicationAt: applicationURL,
            configuration: configuration
        )
    }
}
