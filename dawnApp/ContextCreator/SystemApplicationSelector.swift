//
//  SystemApplicationSelector.swift
//  dawn
//
//  Created by Rafael Venetikides on 24/09/26.
//

import AppKit
import libdawn
import UniformTypeIdentifiers

enum ApplicationSelectionError: Error, LocalizedError, Equatable {
    case invalidApplication
    case missingBundleIdentifier
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidApplication:
            "The selected item is not a valid application."
        case .missingBundleIdentifier:
            "The selected application has no bundle identifier."
        case .unknown:
            "The application could not be selected"
        }
    }
}

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

        guard let applicationURL = panel.url,
            let bundle = Bundle(url: applicationURL)
        else {
            throw ApplicationSelectionError.invalidApplication
        }

        guard let bundleIdentifier = bundle.bundleIdentifier else {
            throw ApplicationSelectionError.missingBundleIdentifier
        }

        let displayName =
            bundle.object(
                forInfoDictionaryKey: "CFBundleDisplayName"
            ) as? String ?? bundle.object(
                forInfoDictionaryKey: "CFBundleName"
            ) as? String ?? applicationURL.deletingPathExtension().lastPathComponent

        return WorkspaceApplication(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            applicationURL: applicationURL
        )
    }
}
