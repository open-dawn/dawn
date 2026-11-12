//
//  AgentUpdatePreparerTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

import Foundation
import Testing
import libdawn

@testable import dawnAgent

@MainActor
@Suite("AgentUpdatePreparer")
struct AgentUpdatePreparerTests {
    private let identity = ComponentIdentity(
        identifier: EventBusMachService.agentBundleIdentifier,
        version: "1.2.0",
        build: "42"
    )

    @Test("Exposes the injected component identity")
    func exposesIdentity() {
        let workspace = WorkspaceUpdatePreparingSpy()
        let lifecycle = AgentLifecycleState()

        let preparer = AgentUpdatePreparer(
            identity: identity,
            workspace: workspace,
            lifecycle: lifecycle
        )

        #expect(preparer.identity == identity)
    }

    @Test("Stops an active workspace and remains ready for update")
    func stopsActiveWorkspace() async throws {
        let workspace = WorkspaceUpdatePreparingSpy(
            activeContextID: UUID()
        )
        let lifecycle = AgentLifecycleState()

        let preparer = AgentUpdatePreparer(
            identity: identity,
            workspace: workspace,
            lifecycle: lifecycle
        )

        try await preparer.prepareForApplicationUpdate()

        #expect(workspace.stopCallCount == 1)
        #expect(lifecycle.phase == .preparingForUpdate)
        #expect(!lifecycle.acceptsMutations)
    }

    @Test("Does not stop an inactive workspace")
    func doesNotStopInactiveWorkspace() async throws {
        let workspace = WorkspaceUpdatePreparingSpy(
            activeContextID: nil
        )
        let lifecycle = AgentLifecycleState()

        let preparer = AgentUpdatePreparer(
            identity: identity,
            workspace: workspace,
            lifecycle: lifecycle
        )

        try await preparer.prepareForApplicationUpdate()

        #expect(workspace.stopCallCount == 0)
        #expect(lifecycle.phase == .preparingForUpdate)
    }

    @Test("Repeated preparation does not stop workspace twice")
    func repeatedPreparationIsIdempotent() async throws {
        let workspace = WorkspaceUpdatePreparingSpy(
            activeContextID: UUID()
        )
        let lifecycle = AgentLifecycleState()

        let preparer = AgentUpdatePreparer(
            identity: identity,
            workspace: workspace,
            lifecycle: lifecycle
        )

        try await preparer.prepareForApplicationUpdate()
        try await preparer.prepareForApplicationUpdate()

        #expect(workspace.stopCallCount == 1)
        #expect(lifecycle.phase == .preparingForUpdate)
    }

    @Test("Failed preparation restores running state and permits retry")
    func failureRestoresRunningState() async throws {
        let workspace = WorkspaceUpdatePreparingSpy(
            activeContextID: UUID()
        )
        workspace.error = PreparationTestError.expected

        let lifecycle = AgentLifecycleState()

        let preparer = AgentUpdatePreparer(
            identity: identity,
            workspace: workspace,
            lifecycle: lifecycle
        )

        await #expect(throws: PreparationTestError.expected) {
            try await preparer.prepareForApplicationUpdate()
        }

        #expect(workspace.stopCallCount == 1)
        #expect(lifecycle.phase == .running)
        #expect(lifecycle.acceptsMutations)

        workspace.error = nil

        try await preparer.prepareForApplicationUpdate()

        #expect(workspace.stopCallCount == 2)
        #expect(lifecycle.phase == .preparingForUpdate)
    }
}

@MainActor
private final class WorkspaceUpdatePreparingSpy:
    WorkspaceUpdatePreparing
{
    var activeContextID: UUID?
    var error: Error?

    private(set) var stopCallCount = 0

    init(activeContextID: UUID? = nil) {
        self.activeContextID = activeContextID
    }

    func stopActiveContext() async throws {
        stopCallCount += 1

        if let error {
            throw error
        }

        activeContextID = nil
    }
}

private enum PreparationTestError: Error, Equatable {
    case expected
}
