//
//  ContextSaving.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 24/09/26.
//

import Foundation
import PaEventKit

@MainActor
protocol ContextSaving: AnyObject {
    @discardableResult
    func createContext(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication]
    ) async throws -> UUID

    func updateContext(_ context: WorkspaceContext) async throws
}

extension PaSettingsContextStore: ContextSaving {}
