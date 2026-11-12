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
            ]
        )

        try await coordinator.prepareForUpdate(update)

        #expect(agent.targetBuilds == ["42"])
        #expect(futureComponent.targetBuilds == ["42"])
    }

    @Test("Succeeds when there are no managed components")
    func succeedsWithoutComponents() async throws {
        let coordinator = UpdateComponentCoordinator(
            components: []
        )

        try await coordinator.prepareForUpdate(update)
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
            ]
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
            components: [first, second, third]
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
            components: [first, failing, later]
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

        let coordinator = UpdateComponentCoordinator(
            components: [component]
        )

        try await coordinator.prepareForUpdate(update)

        await #expect(throws: RecoveryError.expected) {
            try await coordinator.recoverAfterUpdateFailure()
        }

        component.recoveryError = nil

        try await coordinator.recoverAfterUpdateFailure()

        #expect(component.recoveryCallCount == 2)
    }

    @Test("Recovery before preparation does nothing")
    func recoveryBeforePreparationDoesNothing() async throws {
        let component = UpdateComponentSpy(
            identifier: "dawnAgent"
        )

        let coordinator = UpdateComponentCoordinator(
            components: [component]
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
            components: [agent, cli]
        )

        try await coordinator.reconcileAfterUpdate(
            expectedBuild: "42"
        )

        #expect(agent.reconciledBuilds == ["42"])
        #expect(cli.reconciledBuilds == ["42"])
    }
}

@MainActor
private final class UpdateComponentSpy: UpdateComponent {
    let identifier: String

    var preparationError: Error?
    var recoveryError: Error?
    var reconciliationError: Error?

    var recoveryRecorder: RecoveryRecorder?

    private(set) var targetBuilds: [String] = []
    private(set) var recoveryCallCount = 0
    private(set) var reconciledBuilds: [String] = []

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

    func recoverAfterUpdateFailure() async throws {
        recoveryCallCount += 1
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
