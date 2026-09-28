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

    var localizedDescription: String {
        switch self {
        case let .corruptedData(description): "Corrupted data encountered: \(description)"
        case let .encodingFailed(description): "Failed to encode data: \(description)"
        case let .unsupportedSchemaVersion(version): "Schema version \(version) is not supported."
        }
    }
}
