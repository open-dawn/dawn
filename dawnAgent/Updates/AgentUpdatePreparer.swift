//
//  AgentUpdatePreparer.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

import Foundation
import libdawn

@MainActor
protocol AgentUpdatePreparing {
    var identity: ComponentIdentity { get }

    func prepareForApplicationUpdate() async throws
    func cancelApplicationUpdatePreparation()
}

@MainActor
protocol WorkspaceUpdatePreparing: AnyObject {
    var activeContextID: UUID? { get }

    func stopActiveContext() async throws
}

extension WorkspaceRuntime: WorkspaceUpdatePreparing {}

@MainActor
final class AgentLifecycleState {
    enum Phase: Equatable {
        case running
        case preparingForUpdate
    }

    private(set) var phase: Phase = .running

    var acceptsMutations: Bool {
        phase == .running
    }

    func beginUpdatePreparation() {
        phase = .preparingForUpdate
    }

    func cancelUpdatePreparation() {
        phase = .running
    }
}

@MainActor
final class AgentUpdatePreparer: AgentUpdatePreparing {
    let identity: ComponentIdentity

    private let workspace: any WorkspaceUpdatePreparing
    private let lifecycle: AgentLifecycleState

    private var preparationTask: Task<Void, Error>?

    init(
        identity: ComponentIdentity,
        workspace: any WorkspaceUpdatePreparing,
        lifecycle: AgentLifecycleState,
    ) {
        self.identity = identity
        self.workspace = workspace
        self.lifecycle = lifecycle
    }

    func prepareForApplicationUpdate() async throws {
        if let preparationTask {
            try await preparationTask.value
            return
        }

        lifecycle.beginUpdatePreparation()

        let task: Task<Void, Error> = Task { @MainActor [workspace] in
            guard workspace.activeContextID != nil else {
                return
            }

            try await workspace.stopActiveContext()
        }

        preparationTask = task

        do {
            try await task.value
        } catch {
            preparationTask = nil
            lifecycle.cancelUpdatePreparation()
            throw error
        }
    }

    func cancelApplicationUpdatePreparation() {
        preparationTask?.cancel()
        preparationTask = nil
        lifecycle.cancelUpdatePreparation()
    }
}
