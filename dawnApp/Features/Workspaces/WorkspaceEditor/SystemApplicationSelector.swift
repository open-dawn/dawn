//
//  SystemApplicationSelector.swift
//  dawn
//
//  Created by Rafael Venetikides on 24/09/26.
//

import AppKit
import libdawn
import UniformTypeIdentifiers

@MainActor
protocol ApplicationSelecting {
    func selectApplication() async throws -> WorkspaceApplication?
}

@MainActor
struct SystemApplicationSelector: ApplicationSelecting {
    func selectApplication() async throws -> WorkspaceApplication? {
        let panel = NSOpenPanel()

        panel.title = "Select an application"
        panel.prompt = "Add Application"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard await panel.begin() == .OK else {
            return nil
        }

        guard let applicationURL = panel.url else {
            throw ApplicationSelectionError.invalidApplication
        }

        return try WorkspaceApplication.imported(from: applicationURL)
    }
}
