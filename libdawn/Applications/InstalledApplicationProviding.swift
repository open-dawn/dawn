//
//  InstalledApplicationProviding.swift
//  dawn
//
//  Created by Rafael Venetikides on 28/10/26.
//

public protocol InstalledApplicationProviding: Sendable {
    func applications() async throws -> [WorkspaceApplication]
}
