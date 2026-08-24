//
//  SettingsStoreError.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 20/08/26.
//

import Foundation

enum SettingsStoreError: Error, Equatable, Sendable {
    case emptyContextName
    case emptyContextSymbol
    case emptyApplicationBundleIdentifier
    case emptyApplicationDisplayName
    case duplicateApplication(bundleIdentifier: String)
    case duplicateContextIdentifier(UUID)
    case duplicateApplicationIdentifier(UUID)
    case contextNotFound(UUID)
}
