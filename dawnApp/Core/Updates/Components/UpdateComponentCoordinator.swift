//
//  UpdateComponentCoordinator.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

import Foundation

enum UpdateComponentRequirement: Equatable, Sendable {
    case required
    case optional
}

@MainActor
protocol UpdateComponent {
    var identifier: String { get }
    var registrationState: UpdateComponentRegistrationState { get }
    var requirement: UpdateComponentRequirement { get }

    func prepareForUpdate(targetBuild: String) async throws

    func recoverAfterUpdateFailure(previousRegistrationState: UpdateComponentRegistrationState) async throws

    func reconcileAfterUpdate(expectedBuild: String) async throws
}

@MainActor
protocol UpdateComponentCoordinating {
    func prepareForUpdate(_ update: AvailableAppUpdate) async throws

    func recoverAfterUpdateFailure() async throws

    func reconcileAfterUpdate(expectedBuild: String) async throws
}

enum UpdateComponentCoordinatorError: Error, Equatable {
    case preparationAlreadyInProgress
    case recoveryPending
    case duplicateComponentIdentifier(String)
    case missingComponent(String)
    case unexpectedInstalledBuild(actual: String, source: String, target: String)
    case unsupportedRegistrationState(String)
}

@MainActor
final class UpdateComponentCoordinator: UpdateComponentCoordinating {
    private let components: [any UpdateComponent]
    private let journalStore: any UpdateRecoveryJournalStoring
    private let sourceBuildProvider: () throws -> String

    private var preparedComponents: [any UpdateComponent] = []

    init(
        components: [any UpdateComponent],
        journalStore: any UpdateRecoveryJournalStoring,
        sourceBuildProvider: @escaping () throws -> String,
    ) {
        self.components = components
        self.journalStore = journalStore
        self.sourceBuildProvider = sourceBuildProvider
    }

    func prepareForUpdate(_ update: AvailableAppUpdate) async throws {
        guard preparedComponents.isEmpty else {
            throw UpdateComponentCoordinatorError.preparationAlreadyInProgress
        }

        guard !components.isEmpty else {
            return
        }

        guard try journalStore.load() == nil else {
            throw UpdateComponentCoordinatorError.recoveryPending
        }

        let sourceBuild = try sourceBuildProvider()
        let records = try makeRecoveryRecords()

        var journal = UpdateRecoveryJournal(
            sourceBuild: sourceBuild,
            targetBuild: update.buildVersion,
            components: records
        )

        try journalStore.save(journal)

        for index in components.indices {
            journal.components[index].preparationPhase = .preparing
            try journalStore.save(journal)

            let component = components[index]
            preparedComponents.append(component)

            try await component.prepareForUpdate(
                targetBuild: update.buildVersion
            )

            journal.components[index].preparationPhase = .prepared
            try journalStore.save(journal)
        }
    }

    func recoverAfterUpdateFailure() async throws {
        guard let journal = try journalStore.load() else {
            preparedComponents.removeAll()
            return
        }

        let restoredJournal = try await restoreComponents(from: journal)

        try await reconcileComponents(
            expectedBuild: restoredJournal.sourceBuild,
            journal: restoredJournal,
            includesRequiredComponents: false
        )

        try journalStore.clear()
        preparedComponents.removeAll()
    }

    func reconcileAfterUpdate(expectedBuild: String) async throws {
        guard let journal = try journalStore.load() else {
            try await reconcileComponents(
                expectedBuild: expectedBuild,
                journal: nil
            )
            return
        }

        if expectedBuild == journal.sourceBuild {
            try await recoverAfterUpdateFailure()
            return
        }

        guard expectedBuild == journal.targetBuild else {
            throw
                UpdateComponentCoordinatorError
                .unexpectedInstalledBuild(
                    actual: expectedBuild,
                    source: journal.sourceBuild,
                    target: journal.targetBuild
                )
        }

        try await reconcileComponents(
            expectedBuild: expectedBuild,
            journal: journal
        )

        try journalStore.clear()
        preparedComponents.removeAll()
    }

    private func restoreComponents(from storedJournal: UpdateRecoveryJournal) async throws -> UpdateRecoveryJournal {
        var journal = storedJournal

        for index in journal.components.indices.reversed() {
            let record = journal.components[index]

            guard record.preparationPhase != .notStarted else {
                continue
            }

            guard let component = components.first(where: { $0.identifier == record.identifier }) else {
                throw UpdateComponentCoordinatorError.missingComponent(record.identifier)
            }

            try await component.recoverAfterUpdateFailure(previousRegistrationState: record.previousRegistrationState)

            journal.components[index].preparationPhase = .notStarted
            try journalStore.save(journal)
        }

        return journal
    }

    private func makeRecoveryRecords() throws -> [UpdateComponentRecoveryRecord] {
        var identifiers = Set<String>()

        return try components.map { component in
            guard identifiers.insert(component.identifier).inserted else {
                throw UpdateComponentCoordinatorError.duplicateComponentIdentifier(component.identifier)
            }

            let registrationState = component.registrationState

            guard registrationState != .unknown else {
                throw UpdateComponentCoordinatorError.unsupportedRegistrationState(component.identifier)
            }

            return UpdateComponentRecoveryRecord(
                identifier: component.identifier,
                previousRegistrationState: registrationState,
                preparationPhase: .notStarted
            )
        }
    }

    private func reconcileComponents(
        expectedBuild: String,
        journal: UpdateRecoveryJournal?,
        includesRequiredComponents: Bool = true
    ) async throws {
        for component in components {
            guard shouldReconcile(component, journal: journal, includesRequiredComponents: includesRequiredComponents)
            else {
                continue
            }

            try await component.reconcileAfterUpdate(expectedBuild: expectedBuild)
        }
    }

    private func shouldReconcile(
        _ component: any UpdateComponent,
        journal: UpdateRecoveryJournal?,
        includesRequiredComponents: Bool
    ) -> Bool {
        if includesRequiredComponents, component.requirement == .required {
            return true
        }

        let previousState = journal?.components.first(
            where: { $0.identifier == component.identifier }
        )?.previousRegistrationState

        let state = previousState ?? component.registrationState

        switch state {
        case .enabled, .requiresApproval:
            return true

        case .notRegistered, .notFound, .unknown:
            return false
        }
    }
}
