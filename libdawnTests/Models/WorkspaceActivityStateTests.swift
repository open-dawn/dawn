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
        let contextID = UUID()
        let startedAt = Date(timeIntervalSince1970: 100)
        var state = WorkspaceActivityState.empty

        state.activate(
            contextID: contextID,
            at: startedAt
        )

        #expect(state.activeContextID == contextID)
        #expect(state.activeSince == startedAt)
        #expect(state.lastActiveAt(for: contextID) == nil)
    }

    @Test("repeated activation preserves the original start time")
    func repeatedActivation() {
        let contextID = UUID()
        let startedAt = Date(timeIntervalSince1970: 100)
        let repeatedAt = Date(timeIntervalSince1970: 200)
        var state = WorkspaceActivityState.empty

        state.activate(
            contextID: contextID,
            at: startedAt
        )

        state.activate(
            contextID: contextID,
            at: repeatedAt
        )

        #expect(state.activeSince == startedAt)
        #expect(state.lastActiveAt(for: contextID) == nil)
    }

    @Test("switching ends the previous session")
    func switchingContext() {
        let firstID = UUID()
        let secondID = UUID()
        let firstStartedAt = Date(timeIntervalSince1970: 100)
        let switchedAt = Date(timeIntervalSince1970: 200)
        var state = WorkspaceActivityState.empty

        state.activate(
            contextID: firstID,
            at: firstStartedAt
        )

        state.activate(
            contextID: secondID,
            at: switchedAt
        )

        #expect(state.activeContextID == secondID)
        #expect(state.activeSince == switchedAt)
        #expect(
            state.lastActiveAt(for: firstID) == switchedAt
        )
    }

    @Test("stopping records the last-active time")
    func stoppingContext() {
        let contextID = UUID()
        let stoppedAt = Date(timeIntervalSince1970: 200)
        var state = WorkspaceActivityState.empty

        state.activate(
            contextID: contextID,
            at: Date(timeIntervalSince1970: 100)
        )

        state.stop(at: stoppedAt)

        #expect(state.activeContextID == nil)
        #expect(state.activeSince == nil)
        #expect(
            state.lastActiveAt(for: contextID) == stoppedAt
        )
    }

    @Test("reconciliation removes orphaned activity")
    func reconciliation() {
        let retainedID = UUID()
        let removedID = UUID()
        var state = WorkspaceActivityState.empty

        state.activate(
            contextID: removedID,
            at: Date(timeIntervalSince1970: 100)
        )
        state.stop(
            at: Date(timeIntervalSince1970: 200)
        )
        state.activate(
            contextID: retainedID,
            at: Date(timeIntervalSince1970: 300)
        )

        state.reconcile(
            validContextIDs: [retainedID]
        )

        #expect(state.activeContextID == retainedID)
        #expect(
            state.lastActiveAt(for: removedID) == nil
        )
    }

    @Test("activity metadata survives encoding")
    func codableRoundTrip() throws {
        let contextID = UUID()
        var expected = WorkspaceActivityState.empty

        expected.activate(
            contextID: contextID,
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
        let contextID = UUID()
        let otherID = UUID()
        let startedAt = Date(timeIntervalSince1970: 100)
        var state = WorkspaceActivityState.empty

        state.activate(contextID: contextID, at: startedAt)
        state.stop(at: Date(timeIntervalSince1970: 150))
        state.activate(contextID: otherID, at: Date(timeIntervalSince1970: 200))
        state.clearActiveSession(for: otherID)

        #expect(state.activeContextID == nil)
        #expect(state.lastActiveAt(for: contextID) == Date(timeIntervalSince1970: 150))
        #expect(state.lastActiveAt(for: otherID) == nil)
    }
}
