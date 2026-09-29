//
//  SettingsRepository.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/08/26.
//

import Foundation

protocol SettingsRepository: Sendable {
    func load() async throws -> SettingsDocument?
    func save(_ document: SettingsDocument) async throws
}
