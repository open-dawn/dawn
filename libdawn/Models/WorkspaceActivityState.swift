//
//  WorkspaceActivityState.swift
//  dawn
//
//  Created by Rafael Venetikides on 26/10/26.
//

import Foundation

public struct WorkspaceActivityState: Codable, Equatable, Sendable {
    public struct ActiveSession: Codable, Equatable, Sendable {
        public let contextID: UUID
        public let startedAt: Date

        public init(contextID: UUID, startedAt: Date) {
            self.contextID = contextID
            self.startedAt = startedAt
        }
    }

    public private(set) var activeSession: ActiveSession?
    public private(set) var lastActiveAtByContextID: [UUID: Date]

    public var activeContextID: UUID? {
        activeSession?.contextID
    }

    public var activeSince: Date? {
        activeSession?.startedAt
    }

    public static let empty = WorkspaceActivityState()

    public init(activeSession: ActiveSession? = nil, lastActiveAtByContextID: [UUID: Date] = [:]) {
        self.activeSession = activeSession
        self.lastActiveAtByContextID = lastActiveAtByContextID
    }

    public func lastActiveAt(for contextID: UUID) -> Date? {
        lastActiveAtByContextID[contextID]
    }

    public mutating func activate(contextID: UUID, at date: Date) {
        guard activeSession?.contextID != contextID else {
            return
        }

        if let previousSession = activeSession {
            lastActiveAtByContextID[previousSession.contextID] = date
        }

        activeSession = ActiveSession(
            contextID: contextID,
            startedAt: date
        )
    }

    public mutating func stop(at date: Date) {
        guard let activeSession else {
            return
        }

        lastActiveAtByContextID[activeSession.contextID] = date

        self.activeSession = nil
    }

    public mutating func removeContext(id contextID: UUID) {
        if activeSession?.contextID == contextID {
            activeSession = nil
        }

        lastActiveAtByContextID[contextID] = nil
    }

    public mutating func reconcile(validContextIDs: Set<UUID>) {
        if let activeContextID, !validContextIDs.contains(activeContextID) {
            activeSession = nil
        }

        lastActiveAtByContextID = lastActiveAtByContextID.filter {
            validContextIDs.contains($0.key)
        }
    }
}
