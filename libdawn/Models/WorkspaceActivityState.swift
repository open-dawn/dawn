//
//  WorkspaceActivityState.swift
//  dawn
//
//  Created by Rafael Venetikides on 26/10/26.
//

import Foundation

public struct WorkspaceActivityState: Codable, Equatable, Sendable {
    public struct ActiveSession: Codable, Equatable, Sendable {
        public let workspaceID: UUID
        public let startedAt: Date

        public init(workspaceID: UUID, startedAt: Date) {
            self.workspaceID = workspaceID
            self.startedAt = startedAt
        }
    }

    public private(set) var activeSession: ActiveSession?
    public private(set) var lastActiveAtByWorkspaceID: [UUID: Date]

    public var activeWorkspaceID: UUID? {
        activeSession?.workspaceID
    }

    public var activeSince: Date? {
        activeSession?.startedAt
    }

    public static let empty = WorkspaceActivityState()

    public init(activeSession: ActiveSession? = nil, lastActiveAtByWorkspaceID: [UUID: Date] = [:]) {
        self.activeSession = activeSession
        self.lastActiveAtByWorkspaceID = lastActiveAtByWorkspaceID
    }

    public func lastActiveAt(for workspaceID: UUID) -> Date? {
        lastActiveAtByWorkspaceID[workspaceID]
    }

    public mutating func activate(workspaceID: UUID, at date: Date) {
        guard activeSession?.workspaceID != workspaceID else {
            return
        }

        if let previousSession = activeSession {
            lastActiveAtByWorkspaceID[previousSession.workspaceID] = date
        }

        activeSession = ActiveSession(
            workspaceID: workspaceID,
            startedAt: date
        )
    }

    public mutating func stop(at date: Date) {
        guard let activeSession else {
            return
        }

        lastActiveAtByWorkspaceID[activeSession.workspaceID] = date

        self.activeSession = nil
    }

    public mutating func removeWorkspace(id workspaceID: UUID) {
        clearActiveSession(for: workspaceID)
        lastActiveAtByWorkspaceID[workspaceID] = nil
    }

    public mutating func clearActiveSession(for workspaceID: UUID) {
        if activeSession?.workspaceID == workspaceID {
            activeSession = nil
        }
    }

    public mutating func reconcile(validWorkspaceIDs: Set<UUID>) {
        if let activeWorkspaceID, !validWorkspaceIDs.contains(activeWorkspaceID) {
            activeSession = nil
        }

        lastActiveAtByWorkspaceID = lastActiveAtByWorkspaceID.filter {
            validWorkspaceIDs.contains($0.key)
        }
    }
}
