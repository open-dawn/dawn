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
        #expect(runtime.lastRequestedContextID == context.id)
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

        #expect(runtime.lastRequestedContextID == nil)
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
        #expect(runtime.lastRequestedContextID == nil)
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
}

@MainActor
private final class OutOfOrderContextProvider: ContextProviding {
    var contexts: [WorkspaceContext]

    private var requestCount = 0

    private var firstRequestSnapshot: [WorkspaceContext]?
    private var firstRequestContinuation:
        CheckedContinuation<[WorkspaceContext], Never>?

    private var firstRequestWaiter:
        CheckedContinuation<Void, Never>?

    init(contexts: [WorkspaceContext]) {
        self.contexts = contexts
    }

    func getAvailableContexts() async -> [WorkspaceContext] {
        requestCount += 1
        let snapshot = contexts

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
}
