//
//  DawnAgentUpdateComponentTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

import Foundation
import Testing
import libdawn

@testable import dawnApp

@MainActor
@Suite("DawnAgentUpdateComponent")
struct DawnAgentUpdateComponentTests {
    private let identity = ComponentIdentity(
        identifier: EventBusMachService.agentBundleIdentifier,
        version: "1.1.0",
        build: "11"
    )

    @Test("Prepares agent before deactivating its service")
    func preparesBeforeDeactivation() async throws {
        let requester = AgentUpdateEventRequesterSpy()
        requester.response =
            .applicationUpdatePreparationAcknowledged(
                .ready(identity: identity)
            )

        let service = DawnAgentServiceManagerSpy()
        let component = DawnAgentUpdateComponent(
            eventRequester: requester,
            connectionWaiter: AgentUpdateConnectionWaiterSpy(),
            service: service,
        )

        try await component.prepareForUpdate(
            targetBuild: "12"
        )

        #expect(
            requester.events == [
                .prepareForApplicationUpdate(
                    PrepareForApplicationUpdateEvent()
                )
            ]
        )
        #expect(requester.timeouts == [.seconds(5)])
        #expect(service.deactivationCallCount == 1)
    }

    @Test("Preparation failure prevents deactivation")
    func preparationFailurePreventsDeactivation() async {
        let requester = AgentUpdateEventRequesterSpy()
        requester.response =
            .applicationUpdatePreparationAcknowledged(
                .failure(failure: .workspaceShutdownFailed)
            )

        let service = DawnAgentServiceManagerSpy()
        let component = DawnAgentUpdateComponent(
            eventRequester: requester,
            connectionWaiter: AgentUpdateConnectionWaiterSpy(),
            service: service
        )

        await #expect(
            throws: DawnAgentUpdateComponentError.preparationFailed(
                .workspaceShutdownFailed
            )
        ) {
            try await component.prepareForUpdate(
                targetBuild: "12"
            )
        }

        #expect(service.deactivationCallCount == 0)
    }

    @Test("Unexpected response prevents deactivation")
    func unexpectedResponsePreventsDeactivation() async {
        let requester = AgentUpdateEventRequesterSpy()
        requester.response = .debugPong(
            DebugPongEvent(message: "unexpected")
        )

        let service = DawnAgentServiceManagerSpy()
        let component = DawnAgentUpdateComponent(
            eventRequester: requester,
            connectionWaiter: AgentUpdateConnectionWaiterSpy(),
            service: service
        )

        await #expect(
            throws:
                DawnAgentUpdateComponentError
                .unexpectedResponse(.debugPong)
        ) {
            try await component.prepareForUpdate(
                targetBuild: "12"
            )
        }

        #expect(service.deactivationCallCount == 0)
    }

    @Test("Unexpected agent identity prevents deactivation")
    func unexpectedIdentityPreventsDeactivation() async {
        let unexpectedIdentity = ComponentIdentity(
            identifier: "example.unexpected.agent",
            version: "1.1.0",
            build: "11"
        )

        let requester = AgentUpdateEventRequesterSpy()
        requester.response =
            .applicationUpdatePreparationAcknowledged(
                .ready(identity: unexpectedIdentity)
            )

        let service = DawnAgentServiceManagerSpy()
        let component = DawnAgentUpdateComponent(
            eventRequester: requester,
            connectionWaiter: AgentUpdateConnectionWaiterSpy(),
            service: service
        )

        await #expect(
            throws:
                DawnAgentUpdateComponentError
                .unexpectedAgentIdentifier(
                    expected:
                        EventBusMachService.agentBundleIdentifier,
                    actual: unexpectedIdentity.identifier
                )
        ) {
            try await component.prepareForUpdate(
                targetBuild: "12"
            )
        }

        #expect(service.deactivationCallCount == 0)
    }

    @Test("Legacy agent without preparation handler is deactivated")
    func legacyAgentIsDeactivated() async throws {
        let requester = AgentUpdateEventRequesterSpy()
        requester.error = EventAskError.noHandler

        let service = DawnAgentServiceManagerSpy()
        let component = DawnAgentUpdateComponent(
            eventRequester: requester,
            connectionWaiter: AgentUpdateConnectionWaiterSpy(),
            service: service
        )

        try await component.prepareForUpdate(
            targetBuild: "12"
        )

        #expect(service.deactivationCallCount == 1)
    }

    @Test("Disconnected agent service is still deactivated")
    func disconnectedAgentIsDeactivated() async throws {
        let requester = AgentUpdateEventRequesterSpy()
        requester.error = EventRemoteError.notConnected

        let service = DawnAgentServiceManagerSpy()
        let component = DawnAgentUpdateComponent(
            eventRequester: requester,
            connectionWaiter: AgentUpdateConnectionWaiterSpy(),
            service: service
        )

        try await component.prepareForUpdate(
            targetBuild: "12"
        )

        #expect(service.deactivationCallCount == 1)
    }

    @Test("Service deactivation failure is propagated")
    func serviceFailureIsPropagated() async {
        let requester = AgentUpdateEventRequesterSpy()
        requester.response =
            .applicationUpdatePreparationAcknowledged(
                .ready(identity: identity)
            )

        let service = DawnAgentServiceManagerSpy()
        service.error = ComponentTestError.expected

        let component = DawnAgentUpdateComponent(
            eventRequester: requester,
            connectionWaiter: AgentUpdateConnectionWaiterSpy(),
            service: service
        )

        await #expect(throws: ComponentTestError.expected) {
            try await component.prepareForUpdate(
                targetBuild: "12"
            )
        }

        #expect(service.deactivationCallCount == 1)
    }

    @Test("Reconciliation activates agent and accepts target build")
    func reconciliationAcceptsTargetBuild() async throws {
        let requester = AgentUpdateEventRequesterSpy()
        requester.responses = [
            identityResponse(build: "12"),
        ]

        let waiter = AgentUpdateConnectionWaiterSpy()
        let service = DawnAgentServiceManagerSpy()

        let component = DawnAgentUpdateComponent(
            eventRequester: requester,
            connectionWaiter: waiter,
            service: service
        )

        try await component.reconcileAfterUpdate(
            expectedBuild: "12"
        )

        #expect(service.activationCallCount == 1)
        #expect(service.restartCallCount == 0)

        #expect(waiter.waitedAfterGenerations.count == 1)
        #expect(waiter.waitedAfterGenerations[0] == nil)
        #expect(waiter.timeouts == [.seconds(5)])

        #expect(requester.events == [
            .getComponentIdentity(GetComponentIdentityEvent()),
        ])
    }

    @Test("Stale agent is restarted and reconciled")
    func staleAgentIsRestarted() async throws {
        let requester = AgentUpdateEventRequesterSpy()
        requester.responses = [
            identityResponse(build: "11"),
            identityResponse(build: "12"),
        ]

        let waiter = AgentUpdateConnectionWaiterSpy()
        waiter.connectionGeneration = 7

        let service = DawnAgentServiceManagerSpy()

        let component = DawnAgentUpdateComponent(
            eventRequester: requester,
            connectionWaiter: waiter,
            service: service
        )

        try await component.reconcileAfterUpdate(
            expectedBuild: "12"
        )

        #expect(service.activationCallCount == 1)
        #expect(service.restartCallCount == 1)

        #expect(waiter.waitedAfterGenerations.count == 2)
        #expect(waiter.waitedAfterGenerations[0] == nil)
        #expect(waiter.waitedAfterGenerations[1] == 7)

        #expect(requester.events == [
            .getComponentIdentity(GetComponentIdentityEvent()),
            .getComponentIdentity(GetComponentIdentityEvent()),
        ])
    }

    @Test("Stale agent after restart fails reconciliation")
    func staleAgentAfterRestartFails() async {
        let requester = AgentUpdateEventRequesterSpy()
        requester.responses = [
            identityResponse(build: "11"),
            identityResponse(build: "10"),
        ]

        let waiter = AgentUpdateConnectionWaiterSpy()
        let service = DawnAgentServiceManagerSpy()

        let component = DawnAgentUpdateComponent(
            eventRequester: requester,
            connectionWaiter: waiter,
            service: service
        )

        await #expect(
            throws: DawnAgentUpdateComponentError.installedBuildMismatch(
                expected: "12",
                actual: "10"
            )
        ) {
            try await component.reconcileAfterUpdate(
                expectedBuild: "12"
            )
        }

        #expect(service.activationCallCount == 1)
        #expect(service.restartCallCount == 1)
        #expect(requester.events.count == 2)
    }

    @Test("Unexpected agent identifier does not trigger restart")
    func unexpectedIdentifierDoesNotRestart() async {
        let requester = AgentUpdateEventRequesterSpy()
        requester.responses = [
            identityResponse(
                build: "12",
                identifier: "example.unexpected.agent"
            ),
        ]

        let waiter = AgentUpdateConnectionWaiterSpy()
        let service = DawnAgentServiceManagerSpy()

        let component = DawnAgentUpdateComponent(
            eventRequester: requester,
            connectionWaiter: waiter,
            service: service
        )

        await #expect(
            throws: DawnAgentUpdateComponentError.unexpectedAgentIdentifier(
                expected: EventBusMachService.agentBundleIdentifier,
                actual: "example.unexpected.agent"
            )
        ) {
            try await component.reconcileAfterUpdate(
                expectedBuild: "12"
            )
        }

        #expect(service.activationCallCount == 1)
        #expect(service.restartCallCount == 0)
        #expect(requester.events.count == 1)
    }

    @Test("Reports the service registration state")
    func reportsServiceRegistrationState() {
        let service = DawnAgentServiceManagerSpy()
        service.registrationState = .requiresApproval

        let component = DawnAgentUpdateComponent(
            eventRequester: AgentUpdateEventRequesterSpy(),
            connectionWaiter: AgentUpdateConnectionWaiterSpy(),
            service: service
        )

        #expect(component.registrationState == .requiresApproval)
    }

    @Test("Recovery restores the recorded registration state")
    func recoveryRestoresRegistrationState() async throws {
        let service = DawnAgentServiceManagerSpy()

        let component = DawnAgentUpdateComponent(
            eventRequester: AgentUpdateEventRequesterSpy(),
            connectionWaiter: AgentUpdateConnectionWaiterSpy(),
            service: service
        )

        try await component.recoverAfterUpdateFailure(
            previousRegistrationState: .requiresApproval
        )

        #expect(
            service.restoredRegistrationStates == [
                .requiresApproval
            ]
        )
    }

    @Test("Registration restoration failure is propagated")
    func recoveryFailureIsPropagated() async {
        let service = DawnAgentServiceManagerSpy()
        service.error = ComponentTestError.expected

        let component = DawnAgentUpdateComponent(
            eventRequester: AgentUpdateEventRequesterSpy(),
            connectionWaiter: AgentUpdateConnectionWaiterSpy(),
            service: service
        )

        await #expect(throws: ComponentTestError.expected) {
            try await component.recoverAfterUpdateFailure(
                previousRegistrationState: .enabled
            )
        }

        #expect(
            service.restoredRegistrationStates == [.enabled]
        )
    }

    private func identityResponse(
        build: String,
        identifier: String = EventBusMachService.agentBundleIdentifier
    ) -> Event {
        .componentIdentity(
            ComponentIdentityEvent(
                identity: ComponentIdentity(
                    identifier: identifier,
                    version: "1.2.0",
                    build: build
                )
            )
        )
    }
}

@MainActor
private final class AgentUpdateEventRequesterSpy:
    AgentUpdateEventAsking
{
    var response: Event?
    var responses: [Event] = []
    var error: Error?

    private(set) var events: [Event] = []
    private(set) var timeouts: [Duration] = []

    func ask(
        _ event: Event,
        timeout: Duration
    ) async throws -> Event {
        events.append(event)
        timeouts.append(timeout)

        if let error {
            throw error
        }

        if !responses.isEmpty {
            return responses.removeFirst()
        }

        return try #require(response)
    }
}

@MainActor
private final class DawnAgentServiceManagerSpy:
    DawnAgentServiceManaging
{
    var registrationState: UpdateComponentRegistrationState = .notRegistered

    var error: Error?
    private(set) var deactivationCallCount = 0
    private(set) var activationCallCount = 0
    private(set) var restartCallCount = 0
    private(set) var restoredRegistrationStates: [UpdateComponentRegistrationState] = []

    func deactivateForUpdate() async throws {
        deactivationCallCount += 1

        if let error {
            throw error
        }
    }

    func restoreRegistration(_ state: UpdateComponentRegistrationState) async throws {
        restoredRegistrationStates.append(state)

        if let error {
            throw error
        }
    }

    func activateIfNeeded() throws {
        activationCallCount += 1

        if let error {
            throw error
        }
    }

    func restartForReconciliation() async throws {
        restartCallCount += 1

        if let error {
            throw error
        }
    }
}

@MainActor
private final class AgentUpdateConnectionWaiterSpy:
    AgentUpdateConnectionWaiting
{
    var connectionGeneration: UInt = 1
    var error: Error?

    private(set) var waitedAfterGenerations: [UInt?] = []
    private(set) var timeouts: [Duration] = []

    func waitUntilConnected(
        after generation: UInt?,
        timeout: Duration
    ) async throws {
        waitedAfterGenerations.append(generation)
        timeouts.append(timeout)

        if let error {
            throw error
        }

        if generation != nil {
            connectionGeneration += 1
        }
    }
}

private enum ComponentTestError: Error, Equatable {
    case expected
}
