//
//  ContextCreating.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 24/09/26.
//

import Foundation
import PaEventKit

@MainActor
protocol ContextCreating: AnyObject {
    @discardableResult
    func createContext(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication]
    ) async throws -> UUID
}

extension PaSettingsContextStore: ContextCreating {}
