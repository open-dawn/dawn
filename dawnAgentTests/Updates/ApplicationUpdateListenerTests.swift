//
//  ApplicationUpdateListenerTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

import Testing
import libdawn

@testable import dawnAgent

@MainActor
@Suite("ApplicationUpdateListener")
struct ApplicationUpdateListenerTests {
    private let identity = ComponentIdentity(
        identifier: EventBusMachService.agentBundleIdentifier,
        version: "1.2.0",
        build: "42"
    )

    @Test("Identity request replies with agent identity")
    func identityRequestRepliesWithIdentity() async throws {
        let bus = EventBus()
        let preparer = AgentUpdatePreparerSpy(identity: identity)
        let listener = ApplicationUpdateListener(
            bus: bus,
            preparer: preparer
        )

        let reply = try await bus.ask(
            .getComponentIdentity(GetComponentIdentityEvent()),
            timeout: .seconds(1)
        )

        #expect(
            reply
                == .componentIdentity(
                    ComponentIdentityEvent(identity: identity)
                )
        )
        #expect(preparer.prepareCallCount == 0)

        _ = listener
    }

    @Test("Successful preparation replies ready with agent identity")
    func successfulPreparationRepliesReady() async throws {
        let bus = EventBus()
        let preparer = AgentUpdatePreparerSpy(identity: identity)
        let listener = ApplicationUpdateListener(
            bus: bus,
            preparer: preparer
        )

        let reply = try await bus.ask(
            .prepareForApplicationUpdate(
                PrepareForApplicationUpdateEvent()
            ),
            timeout: .seconds(1)
        )

        #expect(preparer.prepareCallCount == 1)
        #expect(
            reply
                == .applicationUpdatePreparationAcknowledged(
                    .ready(identity: identity)
                )
        )

        _ = listener
    }

    @Test("Failed preparation replies with workspace shutdown failure")
    func failedPreparationRepliesWithFailure() async throws {
        let bus = EventBus()
        let preparer = AgentUpdatePreparerSpy(identity: identity)
        preparer.error = PreparationTestError.expected

        let listener = ApplicationUpdateListener(
            bus: bus,
            preparer: preparer
        )

        let reply = try await bus.ask(
            .prepareForApplicationUpdate(
                PrepareForApplicationUpdateEvent()
            ),
            timeout: .seconds(1)
        )

        #expect(preparer.prepareCallCount == 1)
        #expect(
            reply
                == .applicationUpdatePreparationAcknowledged(
                    .failure(failure: .workspaceShutdownFailed)
                )
        )

        _ = listener
    }
}

@MainActor
private final class AgentUpdatePreparerSpy: AgentUpdatePreparing {
    let identity: ComponentIdentity

    var error: Error?
    private(set) var prepareCallCount = 0

    init(identity: ComponentIdentity) {
        self.identity = identity
    }

    func prepareForApplicationUpdate() async throws {
        prepareCallCount += 1

        if let error {
            throw error
        }
    }
}

private enum PreparationTestError: Error {
    case expected
}
