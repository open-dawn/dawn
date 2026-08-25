//
//  WorkspaceApplication.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 19/08/26.
//

import Foundation

public struct WorkspaceApplication: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public var bundleIdentifier: String
    public var displayName: String
    public var applicationURL: URL?

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
