//
//  UpdateComponentCoordinatorTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

import Foundation
import Testing

@testable import dawnApp

@MainActor
@Suite("UpdateComponentCoordinator")
struct UpdateComponentCoordinatorTests {
    private var update: AvailableAppUpdate {
        AvailableAppUpdate(
            displayVersion: "1.2.0",
            buildVersion: "42",
            releaseNotesURL: nil,
            informationURL: nil
        )
    }

    @Test("Prepares every component for target build")
    func preparesEveryComponent() async throws {
        let agent = UpdateComponentSpy(
            identifier: "dawnAgent"
        )

        let futureComponent = UpdateComponentSpy(
            identifier: "future-component"
        )

        let coordinator = UpdateComponentCoordinator(
            components: [
                agent,
                futureComponent,
            ],
            journalStore: UpdateRecoveryJournalStoreSpy(),
            sourceBuildProvider: { "41" }
        )

        try await coordinator.prepareForUpdate(update)

        #expect(agent.targetBuilds == ["42"])
        #expect(futureComponent.targetBuilds == ["42"])
    }

    @Test("Empty component registry does not create a journal")
    func emptyRegistryDoesNotCreateJournal() async throws {
        let store = UpdateRecoveryJournalStoreSpy()
        var sourceBuildCallCount = 0

        let coordinator = UpdateComponentCoordinator(
            components: [],
            journalStore: store,
            sourceBuildProvider: {
                sourceBuildCallCount += 1
                return "41"
            }
        )

        try await coordinator.prepareForUpdate(update)

        #expect(store.savedJournals.isEmpty)
        #expect(store.journal == nil)
        #expect(sourceBuildCallCount == 0)
    }

    @Test("Stops preparation after a component fails")
    func stopsAfterFailure() async {
        let failingComponent = UpdateComponentSpy(
            identifier: "dawnAgent"
        )
        failingComponent.preparationError = PreparationError.expected

        let laterComponent = UpdateComponentSpy(
            identifier: "later-component"
        )

        let coordinator = UpdateComponentCoordinator(
            components: [
                failingComponent,
                laterComponent,
            ],
            journalStore: UpdateRecoveryJournalStoreSpy(),
            sourceBuildProvider: { "41" }
        )

        await #expect(throws: PreparationError.expected) {
            try await coordinator.prepareForUpdate(update)
        }

        #expect(failingComponent.targetBuilds == ["42"])
        #expect(laterComponent.targetBuilds.isEmpty)
    }

    @Test("Recovers prepared components in reverse order")
    func recoversInReverseOrder() async throws {
        let recorder = RecoveryRecorder()

        let first = UpdateComponentSpy(identifier: "first")
        first.recoveryRecorder = recorder

        let second = UpdateComponentSpy(identifier: "second")
        second.recoveryRecorder = recorder

        let third = UpdateComponentSpy(identifier: "third")
        third.recoveryRecorder = recorder

        let coordinator = UpdateComponentCoordinator(
            components: [first, second, third],
            journalStore: UpdateRecoveryJournalStoreSpy(),
            sourceBuildProvider: { "41" }
        )

        try await coordinator.prepareForUpdate(update)
        try await coordinator.recoverAfterUpdateFailure()

        #expect(
            recorder.identifiers
                == ["third", "second", "first"]
        )
    }

    @Test("Recovery includes component whose preparation failed")
    func recoveryIncludesFailingComponent() async {
        let recorder = RecoveryRecorder()

        let first = UpdateComponentSpy(identifier: "first")
        first.recoveryRecorder = recorder

        let failing = UpdateComponentSpy(
            identifier: "failing"
        )
        failing.recoveryRecorder = recorder
        failing.preparationError = PreparationError.expected

        let later = UpdateComponentSpy(identifier: "later")
        later.recoveryRecorder = recorder

        let coordinator = UpdateComponentCoordinator(
            components: [first, failing, later],
            journalStore: UpdateRecoveryJournalStoreSpy(),
            sourceBuildProvider: { "41" }
        )

        await #expect(throws: PreparationError.expected) {
            try await coordinator.prepareForUpdate(update)
        }

        do {
            try await coordinator.recoverAfterUpdateFailure()
        } catch {
            Issue.record("Recovery unexpectedly failed: \(error)")
        }

        #expect(
            recorder.identifiers == ["failing", "first"]
        )
        #expect(later.recoveryCallCount == 0)
    }

    @Test("Failed recovery remains retryable")
    func failedRecoveryCanBeRetried() async throws {
        let component = UpdateComponentSpy(
            identifier: "dawnAgent"
        )
        component.recoveryError = RecoveryError.expected

        let store = UpdateRecoveryJournalStoreSpy()

        let coordinator = UpdateComponentCoordinator(
            components: [component],
            journalStore: store,
            sourceBuildProvider: { "41" }
        )

        try await coordinator.prepareForUpdate(update)

        await #expect(throws: RecoveryError.expected) {
            try await coordinator.recoverAfterUpdateFailure()
        }

        #expect(store.journal != nil)
        #expect(store.clearCallCount == 0)

        component.recoveryError = nil
        try await coordinator.recoverAfterUpdateFailure()

        #expect(component.recoveryCallCount == 2)
        #expect(store.journal == nil)
        #expect(store.clearCallCount == 1)
    }

    @Test("Recovery before preparation does nothing")
    func recoveryBeforePreparationDoesNothing() async throws {
        let component = UpdateComponentSpy(
            identifier: "dawnAgent"
        )

        let coordinator = UpdateComponentCoordinator(
            components: [component],
            journalStore: UpdateRecoveryJournalStoreSpy(),
            sourceBuildProvider: { "41" }
        )

        try await coordinator.recoverAfterUpdateFailure()

        #expect(component.recoveryCallCount == 0)
    }

    @Test("Reconciles every component against installed build")
    func reconcilesEveryComponent() async throws {
        let agent = UpdateComponentSpy(
            identifier: "dawnAgent"
        )

        let cli = UpdateComponentSpy(
            identifier: "dawncli"
        )

        let coordinator = UpdateComponentCoordinator(
            components: [agent, cli],
            journalStore: UpdateRecoveryJournalStoreSpy(),
            sourceBuildProvider: { "41" }
        )

        try await coordinator.reconcileAfterUpdate(
            expectedBuild: "42"
        )

        #expect(agent.reconciledBuilds == ["42"])
        #expect(cli.reconciledBuilds == ["42"])
    }

    @Test("Creates journal with builds and previous registration states")
    func createsInitialJournal() async throws {
        let agent = UpdateComponentSpy(identifier: "dawnAgent")
        agent.registrationState = .enabled

        let helper = UpdateComponentSpy(identifier: "future-component")
        helper.registrationState = .requiresApproval

        let store = UpdateRecoveryJournalStoreSpy()

        let coordinator = UpdateComponentCoordinator(
            components: [agent, helper],
            journalStore: store,
            sourceBuildProvider: { "41" }
        )

        try await coordinator.prepareForUpdate(update)

        let initialJournal = try #require(
            store.savedJournals.first
        )

        #expect(initialJournal.sourceBuild == "41")
        #expect(initialJournal.targetBuild == "42")

        #expect(
            initialJournal.components == [
                UpdateComponentRecoveryRecord(
                    identifier: "dawnAgent",
                    previousRegistrationState: .enabled,
                    preparationPhase: .notStarted
                ),
                UpdateComponentRecoveryRecord(
                    identifier: "future-component",
                    previousRegistrationState: .requiresApproval,
                    preparationPhase: .notStarted
                ),
            ]
        )
    }

    @Test("Persists every component preparation transition")
    func persistsPreparationTransitions() async throws {
        let first = UpdateComponentSpy(identifier: "first")
        let second = UpdateComponentSpy(identifier: "second")
        let store = UpdateRecoveryJournalStoreSpy()

        let coordinator = UpdateComponentCoordinator(
            components: [first, second],
            journalStore: store,
            sourceBuildProvider: { "41" }
        )

        try await coordinator.prepareForUpdate(update)

        let phases = store.savedJournals.map { journal in
            journal.components.map(\.preparationPhase)
        }

        let expected: [[UpdateComponentPreparationPhase]] = [
            [.notStarted, .notStarted],
            [.preparing, .notStarted],
            [.prepared, .notStarted],
            [.prepared, .preparing],
            [.prepared, .prepared],
        ]

        #expect(phases == expected)
    }

    @Test("Pending recovery prevents a new preparation")
    func pendingRecoveryPreventsPreparation() async {
        let component = UpdateComponentSpy(identifier: "dawnAgent")
        let store = UpdateRecoveryJournalStoreSpy()

        store.journal = UpdateRecoveryJournal(
            sourceBuild: "40",
            targetBuild: "41",
            components: [
                UpdateComponentRecoveryRecord(
                    identifier: "dawnAgent",
                    previousRegistrationState: .enabled,
                    preparationPhase: .prepared
                )
            ]
        )

        let coordinator = UpdateComponentCoordinator(
            components: [component],
            journalStore: store,
            sourceBuildProvider: { "41" }
        )

        await #expect(
            throws: UpdateComponentCoordinatorError.recoveryPending
        ) {
            try await coordinator.prepareForUpdate(update)
        }

        #expect(component.targetBuilds.isEmpty)
        #expect(store.savedJournals.isEmpty)
    }

    @Test("Duplicate component identifiers prevent preparation")
    func duplicateIdentifiersPreventPreparation() async {
        let first = UpdateComponentSpy(identifier: "duplicate")
        let second = UpdateComponentSpy(identifier: "duplicate")
        let store = UpdateRecoveryJournalStoreSpy()

        let coordinator = UpdateComponentCoordinator(
            components: [first, second],
            journalStore: store,
            sourceBuildProvider: { "41" }
        )

        await #expect(
            throws:
                UpdateComponentCoordinatorError
                .duplicateComponentIdentifier("duplicate")
        ) {
            try await coordinator.prepareForUpdate(update)
        }

        #expect(first.targetBuilds.isEmpty)
        #expect(second.targetBuilds.isEmpty)
        #expect(store.savedJournals.isEmpty)
    }

    @Test("Failed component remains durably marked as preparing")
    func failedComponentRemainsPreparing() async throws {
        let first = UpdateComponentSpy(identifier: "first")

        let failing = UpdateComponentSpy(identifier: "failing")
        failing.preparationError = PreparationError.expected

        let later = UpdateComponentSpy(identifier: "later")
        let store = UpdateRecoveryJournalStoreSpy()

        let coordinator = UpdateComponentCoordinator(
            components: [first, failing, later],
            journalStore: store,
            sourceBuildProvider: { "41" }
        )

        await #expect(throws: PreparationError.expected) {
            try await coordinator.prepareForUpdate(update)
        }

        let latestJournal = try #require(
            store.savedJournals.last
        )

        #expect(
            latestJournal.components.map(\.preparationPhase) == [
                .prepared,
                .preparing,
                .notStarted,
            ]
        )

        #expect(later.targetBuilds.isEmpty)
    }

    @Test("A new coordinator recovers from the persisted journal")
    func newCoordinatorRecoversPersistedJournal() async throws {
        let originalComponent = UpdateComponentSpy(
            identifier: "dawnAgent"
        )
        originalComponent.registrationState = .enabled

        let store = UpdateRecoveryJournalStoreSpy()

        let originalCoordinator = UpdateComponentCoordinator(
            components: [originalComponent],
            journalStore: store,
            sourceBuildProvider: { "41" }
        )

        try await originalCoordinator.prepareForUpdate(update)

        let relaunchedComponent = UpdateComponentSpy(
            identifier: "dawnAgent"
        )

        let relaunchedCoordinator = UpdateComponentCoordinator(
            components: [relaunchedComponent],
            journalStore: store,
            sourceBuildProvider: { "42" }
        )

        try await relaunchedCoordinator
            .recoverAfterUpdateFailure()

        #expect(originalComponent.recoveryCallCount == 0)
        #expect(relaunchedComponent.recoveryCallCount == 1)

        #expect(
            relaunchedComponent.recoveredRegistrationStates
                == [.enabled]
        )

        #expect(store.journal == nil)
        #expect(store.clearCallCount == 1)
    }

    @Test("Recovery skips components that were not started")
    func recoverySkipsComponentsNotStarted() async throws {
        let prepared = UpdateComponentSpy(identifier: "prepared")
        let untouched = UpdateComponentSpy(identifier: "untouched")

        let store = UpdateRecoveryJournalStoreSpy()
        store.journal = UpdateRecoveryJournal(
            sourceBuild: "41",
            targetBuild: "42",
            components: [
                UpdateComponentRecoveryRecord(
                    identifier: "prepared",
                    previousRegistrationState: .enabled,
                    preparationPhase: .prepared
                ),
                UpdateComponentRecoveryRecord(
                    identifier: "untouched",
                    previousRegistrationState: .notRegistered,
                    preparationPhase: .notStarted
                ),
            ]
        )

        let coordinator = UpdateComponentCoordinator(
            components: [prepared, untouched],
            journalStore: store,
            sourceBuildProvider: { "41" }
        )

        try await coordinator.recoverAfterUpdateFailure()

        #expect(prepared.recoveryCallCount == 1)
        #expect(untouched.recoveryCallCount == 0)
        #expect(store.journal == nil)
    }

    @Test("Recovery progress is persisted after each component")
    func recoveryProgressIsPersisted() async throws {
        let first = UpdateComponentSpy(identifier: "first")
        let second = UpdateComponentSpy(identifier: "second")
        let store = UpdateRecoveryJournalStoreSpy()

        store.journal = UpdateRecoveryJournal(
            sourceBuild: "41",
            targetBuild: "42",
            components: [
                UpdateComponentRecoveryRecord(
                    identifier: "first",
                    previousRegistrationState: .enabled,
                    preparationPhase: .prepared
                ),
                UpdateComponentRecoveryRecord(
                    identifier: "second",
                    previousRegistrationState: .requiresApproval,
                    preparationPhase: .prepared
                ),
            ]
        )

        let coordinator = UpdateComponentCoordinator(
            components: [first, second],
            journalStore: store,
            sourceBuildProvider: { "41" }
        )

        try await coordinator.recoverAfterUpdateFailure()

        let phases = store.savedJournals.map { journal in
            journal.components.map(\.preparationPhase)
        }

        let expected: [[UpdateComponentPreparationPhase]] = [
            [.prepared, .notStarted],
            [.notStarted, .notStarted],
        ]

        #expect(phases == expected)
        #expect(store.clearCallCount == 1)
    }

    @Test("Missing recovery component retains the journal")
    func missingRecoveryComponentFails() async {
        let store = UpdateRecoveryJournalStoreSpy()

        store.journal = UpdateRecoveryJournal(
            sourceBuild: "41",
            targetBuild: "42",
            components: [
                UpdateComponentRecoveryRecord(
                    identifier: "removed-component",
                    previousRegistrationState: .enabled,
                    preparationPhase: .prepared
                )
            ]
        )

        let coordinator = UpdateComponentCoordinator(
            components: [],
            journalStore: store,
            sourceBuildProvider: { "42" }
        )

        await #expect(
            throws:
                UpdateComponentCoordinatorError
                .missingComponent("removed-component")
        ) {
            try await coordinator.recoverAfterUpdateFailure()
        }

        #expect(store.journal != nil)
        #expect(store.clearCallCount == 0)
    }
}

// MARK: Reconciliation

@MainActor
@Suite("UpdateComponentCoordinator reconciliation")
struct UpdateComponentCoordinatorReconciliationTests {
    private var update: AvailableAppUpdate {
        AvailableAppUpdate(
            displayVersion: "1.2.0",
            buildVersion: "42",
            releaseNotesURL: nil,
            informationURL: nil
        )
    }

    @Test("Failed update preserves an inactive required component")
    func failedUpdatePreservesInactiveRequiredComponent() async throws {
        let component = UpdateComponentSpy(identifier: "required")
        component.requirement = .required

        let store = UpdateRecoveryJournalStoreSpy()
        store.journal = makeJournal(
            records: [
                record(
                    identifier: "required",
                    state: .notRegistered
                )
            ]
        )

        let coordinator = makeCoordinator(
            components: [component],
            store: store
        )

        try await coordinator.recoverAfterUpdateFailure()

        #expect(component.recoveryCallCount == 1)
        #expect(component.reconciledBuilds.isEmpty)
        #expect(store.journal == nil)
        #expect(store.clearCallCount == 1)
    }

    @Test("Source build restores and validates an active component")
    func sourceBuildRestoresActiveComponent() async throws {
        let component = UpdateComponentSpy(identifier: "agent")
        component.requirement = .required

        let store = UpdateRecoveryJournalStoreSpy()
        store.journal = makeJournal(
            records: [
                record(
                    identifier: "agent",
                    state: .enabled
                )
            ]
        )

        let coordinator = makeCoordinator(
            components: [component],
            store: store
        )

        try await coordinator.reconcileAfterUpdate(
            expectedBuild: "41"
        )

        #expect(component.recoveryCallCount == 1)
        #expect(
            component.recoveredRegistrationStates == [.enabled]
        )
        #expect(component.reconciledBuilds == ["41"])
        #expect(store.journal == nil)
    }

    @Test("Source reconciliation failure retains the journal")
    func sourceReconciliationFailureRetainsJournal() async throws {
        let component = UpdateComponentSpy(identifier: "agent")
        component.registrationState = .enabled
        component.reconciliationError =
            ReconciliationError.expected

        let store = UpdateRecoveryJournalStoreSpy()
        store.journal = makeJournal(
            records: [
                record(
                    identifier: "agent",
                    state: .enabled
                )
            ]
        )

        let coordinator = makeCoordinator(
            components: [component],
            store: store
        )

        await #expect(throws: ReconciliationError.expected) {
            try await coordinator.recoverAfterUpdateFailure()
        }

        let phases = store.journal?
            .components
            .map(\.preparationPhase)

        #expect(phases == [.notStarted])
        #expect(store.clearCallCount == 0)

        component.reconciliationError = nil

        try await coordinator.recoverAfterUpdateFailure()

        #expect(component.recoveryCallCount == 1)
        #expect(component.reconciledBuilds == ["41", "41"])
        #expect(store.journal == nil)
        #expect(store.clearCallCount == 1)
    }

    @Test("Target build reconciles and clears the journal")
    func targetBuildReconcilesAndClearsJournal() async throws {
        let component = UpdateComponentSpy(identifier: "agent")

        let store = UpdateRecoveryJournalStoreSpy()
        store.journal = makeJournal(
            records: [
                record(
                    identifier: "agent",
                    state: .enabled
                )
            ]
        )

        let coordinator = makeCoordinator(
            components: [component],
            store: store
        )

        try await coordinator.reconcileAfterUpdate(
            expectedBuild: "42"
        )

        #expect(component.recoveryCallCount == 0)
        #expect(component.reconciledBuilds == ["42"])
        #expect(store.journal == nil)
        #expect(store.clearCallCount == 1)
    }

    @Test("Target reconciliation failure retains the journal")
    func targetReconciliationFailureRetainsJournal() async {
        let component = UpdateComponentSpy(identifier: "agent")
        component.reconciliationError =
            ReconciliationError.expected

        let store = UpdateRecoveryJournalStoreSpy()
        store.journal = makeJournal(
            records: [
                record(
                    identifier: "agent",
                    state: .enabled
                )
            ]
        )

        let coordinator = makeCoordinator(
            components: [component],
            store: store
        )

        await #expect(throws: ReconciliationError.expected) {
            try await coordinator.reconcileAfterUpdate(
                expectedBuild: "42"
            )
        }

        #expect(component.recoveryCallCount == 0)
        #expect(component.reconciledBuilds == ["42"])
        #expect(store.journal != nil)
        #expect(store.clearCallCount == 0)
    }

    @Test("Unexpected build retains the journal")
    func unexpectedBuildRetainsJournal() async {
        let component = UpdateComponentSpy(identifier: "agent")
        let store = UpdateRecoveryJournalStoreSpy()

        store.journal = makeJournal(
            records: [
                record(
                    identifier: "agent",
                    state: .enabled
                )
            ]
        )

        let coordinator = makeCoordinator(
            components: [component],
            store: store
        )

        await #expect(
            throws:
                UpdateComponentCoordinatorError
                .unexpectedInstalledBuild(
                    actual: "43",
                    source: "41",
                    target: "42"
                )
        ) {
            try await coordinator.reconcileAfterUpdate(
                expectedBuild: "43"
            )
        }

        #expect(component.recoveryCallCount == 0)
        #expect(component.reconciledBuilds.isEmpty)
        #expect(store.journal != nil)
        #expect(store.clearCallCount == 0)
    }

    @Test("Unknown state prevents preparation")
    func unknownStatePreventsPreparation() async {
        let component = UpdateComponentSpy(identifier: "agent")
        component.registrationState = .unknown

        let store = UpdateRecoveryJournalStoreSpy()
        let coordinator = makeCoordinator(
            components: [component],
            store: store
        )

        await #expect(
            throws:
                UpdateComponentCoordinatorError
                .unsupportedRegistrationState("agent")
        ) {
            try await coordinator.prepareForUpdate(update)
        }

        #expect(component.targetBuilds.isEmpty)
        #expect(store.savedJournals.isEmpty)
        #expect(store.journal == nil)
    }

    @Test("New required component reconciles but new optional component does not")
    func newComponentRequirementsAreRespected() async throws {
        let required = UpdateComponentSpy(identifier: "required")
        required.requirement = .required
        required.registrationState = .notFound

        let optional = UpdateComponentSpy(identifier: "optional")
        optional.requirement = .optional
        optional.registrationState = .notRegistered

        let store = UpdateRecoveryJournalStoreSpy()
        store.journal = makeJournal(records: [])

        let coordinator = makeCoordinator(
            components: [required, optional],
            store: store
        )

        try await coordinator.reconcileAfterUpdate(
            expectedBuild: "42"
        )

        #expect(required.reconciledBuilds == ["42"])
        #expect(optional.reconciledBuilds.isEmpty)
        #expect(store.journal == nil)
    }

    @Test("Optional components preserve their previous state")
    func optionalComponentsPreservePreviousState() async throws {
        let enabled = UpdateComponentSpy(
            identifier: "enabled-optional"
        )
        enabled.requirement = .optional
        enabled.registrationState = .notRegistered

        let disabled = UpdateComponentSpy(
            identifier: "disabled-optional"
        )
        disabled.requirement = .optional
        disabled.registrationState = .enabled

        let store = UpdateRecoveryJournalStoreSpy()
        store.journal = makeJournal(
            records: [
                record(
                    identifier: "enabled-optional",
                    state: .enabled
                ),
                record(
                    identifier: "disabled-optional",
                    state: .notRegistered
                ),
            ]
        )

        let coordinator = makeCoordinator(
            components: [enabled, disabled],
            store: store
        )

        try await coordinator.reconcileAfterUpdate(
            expectedBuild: "42"
        )

        #expect(enabled.reconciledBuilds == ["42"])
        #expect(disabled.reconciledBuilds.isEmpty)
    }

    @Test("Removed component does not block target reconciliation")
    func removedComponentDoesNotBlockTarget() async throws {
        let store = UpdateRecoveryJournalStoreSpy()
        store.journal = makeJournal(
            records: [
                record(
                    identifier: "removed-component",
                    state: .enabled
                )
            ]
        )

        let coordinator = makeCoordinator(
            components: [],
            store: store
        )

        try await coordinator.reconcileAfterUpdate(
            expectedBuild: "42"
        )

        #expect(store.journal == nil)
        #expect(store.clearCallCount == 1)
    }

    @Test("Normal launch reconciles required and active optional components")
    func normalLaunchSelectsComponents() async throws {
        let required = UpdateComponentSpy(identifier: "required")
        required.requirement = .required
        required.registrationState = .notRegistered

        let enabledOptional = UpdateComponentSpy(
            identifier: "enabled-optional"
        )
        enabledOptional.requirement = .optional
        enabledOptional.registrationState = .enabled

        let disabledOptional = UpdateComponentSpy(
            identifier: "disabled-optional"
        )
        disabledOptional.requirement = .optional
        disabledOptional.registrationState = .notRegistered

        let store = UpdateRecoveryJournalStoreSpy()

        let coordinator = makeCoordinator(
            components: [
                required,
                enabledOptional,
                disabledOptional,
            ],
            store: store
        )

        try await coordinator.reconcileAfterUpdate(
            expectedBuild: "42"
        )

        #expect(required.reconciledBuilds == ["42"])
        #expect(enabledOptional.reconciledBuilds == ["42"])
        #expect(disabledOptional.reconciledBuilds.isEmpty)
        #expect(store.clearCallCount == 0)
    }

    private func makeCoordinator(
        components: [any UpdateComponent],
        store: UpdateRecoveryJournalStoreSpy
    ) -> UpdateComponentCoordinator {
        UpdateComponentCoordinator(
            components: components,
            journalStore: store,
            sourceBuildProvider: { "41" }
        )
    }

    private func makeJournal(
        records: [UpdateComponentRecoveryRecord]
    ) -> UpdateRecoveryJournal {
        UpdateRecoveryJournal(
            sourceBuild: "41",
            targetBuild: "42",
            components: records
        )
    }

    private func record(
        identifier: String,
        state: UpdateComponentRegistrationState
    ) -> UpdateComponentRecoveryRecord {
        UpdateComponentRecoveryRecord(
            identifier: identifier,
            previousRegistrationState: state,
            preparationPhase: .prepared
        )
    }
}

@MainActor
private final class UpdateComponentSpy: UpdateComponent {
    let identifier: String
    var registrationState: UpdateComponentRegistrationState = .notRegistered
    var requirement: UpdateComponentRequirement = .required

    var preparationError: Error?
    var recoveryError: Error?
    var reconciliationError: Error?

    var recoveryRecorder: RecoveryRecorder?

    private(set) var targetBuilds: [String] = []
    private(set) var recoveryCallCount = 0
    private(set) var reconciledBuilds: [String] = []
    private(set) var recoveredRegistrationStates: [UpdateComponentRegistrationState] = []

    init(identifier: String) {
        self.identifier = identifier
    }

    func prepareForUpdate(
        targetBuild: String
    ) async throws {
        targetBuilds.append(targetBuild)

        if let preparationError {
            throw preparationError
        }
    }

    func recoverAfterUpdateFailure(previousRegistrationState: UpdateComponentRegistrationState) async throws {
        recoveryCallCount += 1
        recoveredRegistrationStates.append(previousRegistrationState)
        recoveryRecorder?.identifiers.append(identifier)

        if let recoveryError {
            throw recoveryError
        }
    }

    func reconcileAfterUpdate(expectedBuild: String) async throws {
        reconciledBuilds.append(expectedBuild)

        if let reconciliationError {
            throw reconciliationError
        }
    }
}

private final class UpdateRecoveryJournalStoreSpy:
    UpdateRecoveryJournalStoring
{
    var journal: UpdateRecoveryJournal?

    private(set) var savedJournals: [UpdateRecoveryJournal] = []
    private(set) var clearCallCount = 0

    func load() throws -> UpdateRecoveryJournal? {
        journal
    }

    func save(_ journal: UpdateRecoveryJournal) throws {
        self.journal = journal
        savedJournals.append(journal)
    }

    func clear() throws {
        journal = nil
        clearCallCount += 1
    }
}

@MainActor
private final class RecoveryRecorder {
    var identifiers: [String] = []
}

private enum PreparationError: Error, Equatable {
    case expected
}

private enum RecoveryError: Error, Equatable {
    case expected
}

private enum ReconciliationError: Error, Equatable {
    case expected
}
