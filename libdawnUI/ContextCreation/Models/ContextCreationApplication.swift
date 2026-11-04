//
//  ContextCreationApplication.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

import AppKit
import Foundation

public struct ContextCreationApplication: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let bundleIdentifier: String
    public let displayName: String
    public let applicationURL: URL?

    public init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        displayName: String,
        applicationURL: URL? = nil
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.applicationURL = applicationURL
    }
}

struct ContextCreationApplicationItem: Identifiable {
    let application: ContextCreationApplication
    let icon: NSImage

    var id: UUID {
        application.id
    }

    var name: String {
        application.displayName
    }
}
