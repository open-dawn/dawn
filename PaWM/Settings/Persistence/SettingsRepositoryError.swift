//
//  SettingsRepositoryError.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 19/08/26.
//

import Foundation

enum SettingsRepositoryError: Error, Equatable, Sendable {
    case corruptedData(description: String)
    case encodingFailed(description: String)
    case unsupportedSchemaVersion(Int)
}
