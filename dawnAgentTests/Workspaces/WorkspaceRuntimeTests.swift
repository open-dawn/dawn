//
//  WorkspaceRuntimeTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 06/10/26.
//

import Foundation
import Testing
import libdawn

@testable import dawnAgent

@MainActor
@Suite("WorkspaceRuntime")
struct WorkspaceRuntimeTests {
    @Test("Refresh exposes the authoritative context snapshot")
    func refreshLoadsContexts() async throws {
        let expectedContexts = [
            WorkspaceContext(
                name: "Work",
                symbol: "briefcase"
            ),
            WorkspaceContext(
                name: "Personal",
                symbol: "person"
            ),
        ]

        let contextManager = FakeContextManager()
        contextManager.contexts = expectedContexts

        let runtime = WorkspaceRuntime(
            contextManager: contextManager,
            contextSwitching: ContextSwitchingSpy()
        )

        await runtime.refresh()

        #expect(runtime.contexts == expectedContexts)
    }

    @Test("Creating a context refreshes observable contexts")
    func createRefreshesContexts() async throws {
        let contextManager = FakeContextManager()
        let runtime = WorkspaceRuntime(
            contextManager: contextManager,
            contextSwitching: ContextSwitchingSpy()
        )

        let createdContext = try await runtime.createContext(
            name: "Work",
            symbol: "briefcase",
            applications: []
        )

        #expect(runtime.contexts == [createdContext])
        #expect(contextManager.contexts == [createdContext])
    }

    @Test("Activating a context delegates to the switcher")
    func activateDelegatesToSwitcher() async throws {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )

        let contextManager = FakeContextManager()
        contextManager.contexts = [context]

        let switcher = ContextSwitchingSpy()

        let runtime = WorkspaceRuntime(
            contextManager: contextManager,
            contextSwitching: switcher
        )

        try await runtime.activateContext(id: context.id)

        #expect(switcher.switchedContexts == [context])
        #expect(runtime.activeContextID == context.id)
    }

    @Test("Activating a missing context fails")
    func activatingMissingContextFails() async {
        let missingID = UUID()

        let runtime = WorkspaceRuntime(
            contextManager: FakeContextManager(),
            contextSwitching: ContextSwitchingSpy()
        )

        await #expect(
            throws: SettingsStoreError.contextNotFound(missingID)
        ) {
            try await runtime.activateContext(id: missingID)
        }

        #expect(runtime.activeContextID == nil)
    }

    @Test("Deleting the active context clears its active state")
    func deletingActiveContextClearsSelection() async throws {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )

        let contextManager = FakeContextManager()
        contextManager.contexts = [context]

        let runtime = WorkspaceRuntime(
            contextManager: contextManager,
            contextSwitching: ContextSwitchingSpy()
        )

        try await runtime.activateContext(id: context.id)
        try await runtime.deleteContext(id: context.id)

        #expect(runtime.contexts.isEmpty)
        #expect(runtime.activeContextID == nil)
    }

    @Test("Older refresh cannot overwrite a newer snapshot")
    func olderRefreshCannotOverwriteNewerSnapshot() async throws {
        let oldContexts = [
            WorkspaceContext(
                name: "Old",
                symbol: "clock"
            )
        ]

        let newContexts = [
            WorkspaceContext(
                name: "New",
                symbol: "sparkles"
            )
        ]

        let contextManager = OutOfOrderContextProvider(contexts: oldContexts)

        let runtime = WorkspaceRuntime(
            contextManager: contextManager,
            contextSwitching: ContextSwitchingSpy()
        )

        let olderRefresh = Task { @MainActor in
            await runtime.refresh()
        }

        await contextManager.waitUntilFirstRequest()

        contextManager.contexts = newContexts
        await runtime.refresh()

        #expect(runtime.contexts == newContexts)

        contextManager.resumeFirstRequest()
        await olderRefresh.value

        #expect(runtime.contexts == newContexts)
    }

    @Test("Failed activation preserves the previously active context")
    func failedActivationPreservesSelection() async throws {
        let initiallyActiveContext = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )

        let failingContext = WorkspaceContext(
            name: "Personal",
            symbol: "person"
        )

        let contextManager = FakeContextManager()
        contextManager.contexts = [
            initiallyActiveContext,
            failingContext
        ]

        let switcher = ContextSwitchingSpy()

        let runtime = WorkspaceRuntime(
            contextManager: contextManager,
            contextSwitching: switcher
        )

        try await runtime.activateContext(
            id: initiallyActiveContext.id
        )

        switcher.error = ContextSwitchingTestError.failed

        await #expect(throws: ContextSwitchingTestError.failed) {
            try await runtime.activateContext(id: failingContext.id)
        }

        #expect(runtime.activeContextID == initiallyActiveContext.id)

        #expect(switcher.switchedContexts == [initiallyActiveContext])
    }

    @Test("Switch context replies with unexpected failure when activation fails")
    func switchContextRepliesWithActivationFailure() async throws {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )

        let contextManager = FakeContextManager()
        contextManager.contexts = [context]

        let switcher = ContextSwitchingSpy()
        switcher.error = ContextSwitchingTestError.failed

        let workspace = WorkspaceRuntime(
            contextManager: contextManager,
            contextSwitching: switcher
        )

        let bus = EventBus()
        let listener = WindowManagerListener(
            bus: bus,
            workspace: workspace
        )

        let response = try await bus.ask(
            .switchContext(
                SwitchContextEvent(contextID: context.id)
            )
        )

        #expect(
            response == .contextMutationAcknowledged(
                .failure(failure: .unexpected)
            )
        )
        #expect(workspace.activeContextID == nil)

        _ = listener
    }

    @Test("Activating a context records persisted activity")
    func activateRecordsActivity() async throws {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )

        let activatedAt = Date(timeIntervalSince1970: 100)

        let contextManager = FakeContextManager()
        contextManager.contexts = [context]

        let switcher = ContextSwitchingSpy()
        let clock = TestWorkspaceClock(
            now: activatedAt
        )

        let runtime = WorkspaceRuntime(
            contextManager: contextManager,
            contextSwitching: switcher,
            clock: clock
        )

        try await runtime.activateContext(id: context.id)

        #expect(switcher.switchedContexts == [context])
        #expect(runtime.activeContextID == context.id)
        #expect(runtime.activeSince == activatedAt)
        #expect(contextManager.workspaceActivity == runtime.workspaceActivity)
    }

    @Test("Refresh loads persisted workspace activity")
    func refreshLoadsActivity() async {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )

        let activeSince = Date(timeIntervalSince1970: 100)

        let contextManager = FakeContextManager()
        contextManager.contexts = [context]
        contextManager.workspaceActivity.activate(
            contextID: context.id,
            at: activeSince
        )

        let runtime = WorkspaceRuntime(
            contextManager: contextManager,
            contextSwitching: ContextSwitchingSpy()
        )

        await runtime.refresh()

        #expect(runtime.activeContextID == context.id)
        #expect(runtime.activeSince == activeSince)
    }

    @Test("Stopping clears active state using the injected clock")
    func stopClearsActiveState() async throws {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )
        let clock = TestWorkspaceClock(
            now: Date(timeIntervalSince1970: 100)
        )

        let contextManager = FakeContextManager()
        contextManager.contexts = [context]

        let runtime = WorkspaceRuntime(
            contextManager: contextManager,
            contextSwitching: ContextSwitchingSpy(),
            clock: clock
        )

        try await runtime.activateContext(id: context.id)

        let stoppedAt = Date(timeIntervalSince1970: 200)
        clock.now = stoppedAt

        try await runtime.stopActiveContext()

        #expect(runtime.activeContextID == nil)
        #expect(runtime.activeSince == nil)
        #expect(runtime.lastActiveAt(for: context.id) == stoppedAt)
    }
}

@MainActor
private final class OutOfOrderContextProvider: WorkspaceManaging {
    var contexts: [WorkspaceContext]
    var workspaceActivity: WorkspaceActivityState = .empty

    private var requestCount = 0

    private var firstRequestSnapshot: WorkspaceSnapshot?
    private var firstRequestContinuation:
    CheckedContinuation<WorkspaceSnapshot, Never>?

    private var firstRequestWaiter:
        CheckedContinuation<Void, Never>?

    init(contexts: [WorkspaceContext]) {
        self.contexts = contexts
    }

    func getAvailableContexts() async -> [WorkspaceContext] {
        contexts
    }

    func waitUntilFirstRequest() async {
        guard firstRequestContinuation == nil else {
            return
        }

        await withCheckedContinuation {
            firstRequestWaiter = $0
        }
    }

    func resumeFirstRequest() {
        guard
            let snapshot = firstRequestSnapshot,
            let continuation = firstRequestContinuation
        else {
            return
        }

        firstRequestSnapshot = nil
        firstRequestContinuation = nil

        continuation.resume(returning: snapshot)
    }

    func getContext(id: UUID) async -> WorkspaceContext? {
        contexts.first { $0.id == id }
    }

    func createContext(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication]
    ) async throws -> WorkspaceContext {
        fatalError("Not used by this test")
    }

    func updateContext(_ context: WorkspaceContext) async throws {
        fatalError("Not used by this test")
    }

    func deleteContext(id: UUID) async throws {
        fatalError("Not used by this test")
    }

    func getWorkspaceActivity() async -> WorkspaceActivityState {
        workspaceActivity
    }

    func recordContextActivation(contextID: UUID, at date: Date) async throws -> WorkspaceActivityState {
        guard contexts.contains(where: { $0.id == contextID }) else {
            throw SettingsStoreError.contextNotFound(contextID)
        }

        workspaceActivity.activate(
            contextID: contextID,
            at: date
        )

        return workspaceActivity
    }

    func stopActiveContext(at date: Date) async throws -> WorkspaceActivityState {
        workspaceActivity.stop(at: date)
        return workspaceActivity
    }

    func getWorkspaceSnapshot() async -> WorkspaceSnapshot {
        requestCount += 1

        let snapshot = WorkspaceSnapshot(
            contexts: contexts,
            activity: workspaceActivity
        )

        guard requestCount == 1 else {
            return snapshot
        }

        firstRequestSnapshot = snapshot

        return await withCheckedContinuation { continuation in
            firstRequestContinuation = continuation

            firstRequestWaiter?.resume()
            firstRequestWaiter = nil
        }
    }
}

@MainActor
private final class TestWorkspaceClock: WorkspaceClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private enum ContextSwitchingTestError: Error, Equatable {
    case failed
}
