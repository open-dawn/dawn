//
//  UpdateRecoveryJournal.swift
//  dawn
//
//  Created by Rafael Venetikides on 12/11/26.
//

import Foundation

enum UpdateComponentRegistrationState: String, Codable, Equatable, Sendable {
    case enabled
    case requiresApproval
    case notRegistered
    case notFound
    case unknown
}

enum UpdateComponentPreparationPhase: String, Codable, Equatable, Sendable {
    case notStarted
    case preparing
    case prepared
}

struct UpdateComponentRecoveryRecord: Codable, Equatable, Sendable {
    let identifier: String
    let previousRegistrationState: UpdateComponentRegistrationState
    var preparationPhase: UpdateComponentPreparationPhase
}

struct UpdateRecoveryJournal: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let sourceBuild: String
    let targetBuild: String
    var components: [UpdateComponentRecoveryRecord]

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        sourceBuild: String,
        targetBuild: String,
        components: [UpdateComponentRecoveryRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.sourceBuild = sourceBuild
        self.targetBuild = targetBuild
        self.components = components
    }
}
