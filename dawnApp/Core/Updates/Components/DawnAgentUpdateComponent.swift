//
//  DawnAgentUpdateComponent.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

import Foundation
import libdawn

@MainActor
protocol AgentUpdateEventAsking {
    func ask(_ event: Event, timeout: Duration) async throws -> Event
}

extension RemoteEventBus: AgentUpdateEventAsking {}

@MainActor
protocol AgentUpdateConnectionWaiting {
    var connectionGeneration: UInt { get }

    func waitUntilConnected(after generation: UInt?, timeout: Duration) async throws
}

@MainActor
protocol DawnAgentServiceManaging {
    var registrationState: UpdateComponentRegistrationState { get }

    func activateIfNeeded() throws
    func deactivateForUpdate() async throws
    func restoreRegistration(_ state: UpdateComponentRegistrationState) async throws
    func restartForReconciliation() async throws
}

enum DawnAgentUpdateComponentError: Error, Equatable {
    case unexpectedResponse(EventKind)

    case unexpectedAgentIdentifier(expected: String, actual: String)

    case preparationFailed(ApplicationUpdatePrepAcknowledgement.Failure)

    case installedBuildMismatch(expected: String, actual: String)
}

@MainActor
final class DawnAgentUpdateComponent: UpdateComponent {
    let identifier = EventBusMachService.agentBundleIdentifier
    var registrationState: UpdateComponentRegistrationState {
        service.registrationState
    }
    let requirement = UpdateComponentRequirement.required

    private let eventRequester: any AgentUpdateEventAsking
    private let connectionWaiter: any AgentUpdateConnectionWaiting
    private let service: any DawnAgentServiceManaging
    private let preparationTimeout: Duration

    init(
        eventRequester: any AgentUpdateEventAsking,
        connectionWaiter: any AgentUpdateConnectionWaiting,
        service: any DawnAgentServiceManaging,
        preparationTimeout: Duration = .seconds(5)
    ) {
        self.eventRequester = eventRequester
        self.connectionWaiter = connectionWaiter
        self.service = service
        self.preparationTimeout = preparationTimeout
    }

    func prepareForUpdate(targetBuild: String) async throws {
        do {
            let response = try await eventRequester.ask(
                .prepareForApplicationUpdate(PrepareForApplicationUpdateEvent()),
                timeout: preparationTimeout
            )

            try validate(response)
        } catch {
            guard canContinueWithoutAcknowledgement(error) else {
                throw error
            }
        }

        try await service.deactivateForUpdate()
    }

    private func validate(_ response: Event) throws {
        guard case .applicationUpdatePreparationAcknowledged(let acknowledgement) = response else {
            throw DawnAgentUpdateComponentError.unexpectedResponse(response.kind)
        }

        switch acknowledgement {
        case let .ready(identity):
            try validateAgentIdentity(identity)

        case let .failure(failure):
            throw DawnAgentUpdateComponentError.preparationFailed(failure)
        }
    }

    private func validateInstalledBuild(expectedBuild: String) async throws {
        let response = try await eventRequester.ask(
            .getComponentIdentity(GetComponentIdentityEvent()),
            timeout: preparationTimeout
        )

        guard case let .componentIdentity(payload) = response else {
            throw DawnAgentUpdateComponentError.unexpectedResponse(response.kind)
        }

        try validateAgentIdentity(payload.identity)

        guard payload.identity.build == expectedBuild else {
            throw DawnAgentUpdateComponentError
                .installedBuildMismatch(expected: expectedBuild, actual: payload.identity.build)
        }
    }

    private func canContinueWithoutAcknowledgement(_ error: Error) -> Bool {
        if let askError = error as? EventAskError {
            return askError == .noHandler
        }

        if let remoteError = error as? EventRemoteError {
            return remoteError == .notConnected
        }

        return false
    }

    func recoverAfterUpdateFailure(previousRegistrationState: UpdateComponentRegistrationState) async throws {
        try await service.restoreRegistration(previousRegistrationState)

        guard previousRegistrationState == .enabled else {
            return
        }

        try await connectionWaiter.waitUntilConnected(
            after: nil,
            timeout: preparationTimeout
        )

        let response = try await eventRequester.ask(
            .cancelApplicationUpdatePreparation(CancelApplicationUpdatePreparationEvent()),
            timeout: preparationTimeout
        )

        try validatePreparationCancellation(response)
    }

    private func validatePreparationCancellation(_ response: Event) throws {
        guard case let .applicationUpdatePreparationCancelled(acknowledgement) = response else {
            throw DawnAgentUpdateComponentError.unexpectedResponse(response.kind)
        }

        try validateAgentIdentity(acknowledgement.identity)
    }

    private func validateAgentIdentity(_ identity: ComponentIdentity) throws {
        guard identity.identifier == identifier else {
            throw DawnAgentUpdateComponentError
                .unexpectedAgentIdentifier(expected: identifier, actual: identity.identifier)
        }
    }

    func reconcileAfterUpdate(expectedBuild: String) async throws {
        try service.activateIfNeeded()

        try await connectionWaiter.waitUntilConnected(after: nil, timeout: preparationTimeout)

        do {
            try await validateInstalledBuild(expectedBuild: expectedBuild)
        } catch let error as DawnAgentUpdateComponentError {
            guard case .installedBuildMismatch  = error else {
                throw error
            }

            let previousGeneration = connectionWaiter.connectionGeneration

            try await service.restartForReconciliation()

            try await connectionWaiter.waitUntilConnected(after: previousGeneration, timeout: preparationTimeout)

            try await validateInstalledBuild(expectedBuild: expectedBuild)
        }
    }
}
