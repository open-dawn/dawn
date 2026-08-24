//
//  WorkspaceApplication.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 19/08/26.
//

import Foundation

struct WorkspaceApplication: Identifiable, Sendable, Codable, Equatable {
    let id: UUID
    var bundleIdentifier: String
    var displayName: String
    var applicationURL: URL?

    init(
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
