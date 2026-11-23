//
//  WorkspaceActivityStateTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 26/10/26.
//

import Foundation
import Testing

@testable import libdawn

@MainActor
@Suite("Workspace activity state")
struct WorkspaceActivityStateTests {
    @Test("first activation starts an active session")
    func firstActivation() async throws {
        let workspaceID = UUID()
        let startedAt = Date(timeIntervalSince1970: 100)
        var state = WorkspaceActivityState.empty

        state.activate(
            workspaceID: workspaceID,
            at: startedAt
        )

        #expect(state.activeWorkspaceID == workspaceID)
        #expect(state.activeSince == startedAt)
        #expect(state.lastActiveAt(for: workspaceID) == nil)
    }

    @Test("repeated activation preserves the original start time")
    func repeatedActivation() {
        let workspaceID = UUID()
        let startedAt = Date(timeIntervalSince1970: 100)
        let repeatedAt = Date(timeIntervalSince1970: 200)
        var state = WorkspaceActivityState.empty

        state.activate(
            workspaceID: workspaceID,
            at: startedAt
        )

        state.activate(
            workspaceID: workspaceID,
            at: repeatedAt
        )

        #expect(state.activeSince == startedAt)
        #expect(state.lastActiveAt(for: workspaceID) == nil)
    }

    @Test("switching ends the previous session")
    func switchingWorkspace() {
        let firstID = UUID()
        let secondID = UUID()
        let firstStartedAt = Date(timeIntervalSince1970: 100)
        let switchedAt = Date(timeIntervalSince1970: 200)
        var state = WorkspaceActivityState.empty

        state.activate(
            workspaceID: firstID,
            at: firstStartedAt
        )

        state.activate(
            workspaceID: secondID,
            at: switchedAt
        )

        #expect(state.activeWorkspaceID == secondID)
        #expect(state.activeSince == switchedAt)
        #expect(
            state.lastActiveAt(for: firstID) == switchedAt
        )
    }

    @Test("stopping records the last-active time")
    func stoppingWorkspace() {
        let workspaceID = UUID()
        let stoppedAt = Date(timeIntervalSince1970: 200)
        var state = WorkspaceActivityState.empty

        state.activate(
            workspaceID: workspaceID,
            at: Date(timeIntervalSince1970: 100)
        )

        state.stop(at: stoppedAt)

        #expect(state.activeWorkspaceID == nil)
        #expect(state.activeSince == nil)
        #expect(
            state.lastActiveAt(for: workspaceID) == stoppedAt
        )
    }

    @Test("reconciliation removes orphaned activity")
    func reconciliation() {
        let retainedID = UUID()
        let removedID = UUID()
        var state = WorkspaceActivityState.empty

        state.activate(
            workspaceID: removedID,
            at: Date(timeIntervalSince1970: 100)
        )
        state.stop(
            at: Date(timeIntervalSince1970: 200)
        )
        state.activate(
            workspaceID: retainedID,
            at: Date(timeIntervalSince1970: 300)
        )

        state.reconcile(
            validWorkspaceIDs: [retainedID]
        )

        #expect(state.activeWorkspaceID == retainedID)
        #expect(
            state.lastActiveAt(for: removedID) == nil
        )
    }

    @Test("activity metadata survives encoding")
    func codableRoundTrip() throws {
        let workspaceID = UUID()
        var expected = WorkspaceActivityState.empty

        expected.activate(
            workspaceID: workspaceID,
            at: Date(timeIntervalSince1970: 100)
        )

        let data = try JSONEncoder().encode(expected)
        let decoded = try JSONDecoder().decode(
            WorkspaceActivityState.self,
            from: data
        )

        #expect(decoded == expected)
    }

    @Test("clearing the active session keeps last-active history")
    func clearActiveSessionKeepsHistory() {
        let workspaceID = UUID()
        let otherID = UUID()
        let startedAt = Date(timeIntervalSince1970: 100)
        var state = WorkspaceActivityState.empty

        state.activate(workspaceID: workspaceID, at: startedAt)
        state.stop(at: Date(timeIntervalSince1970: 150))
        state.activate(workspaceID: otherID, at: Date(timeIntervalSince1970: 200))
        state.clearActiveSession(for: otherID)

        #expect(state.activeWorkspaceID == nil)
        #expect(state.lastActiveAt(for: workspaceID) == Date(timeIntervalSince1970: 150))
        #expect(state.lastActiveAt(for: otherID) == nil)
    }
}
