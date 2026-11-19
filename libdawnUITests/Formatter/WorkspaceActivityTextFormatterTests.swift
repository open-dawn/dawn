//
//  WorkspaceActivityTextFormatterTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 26/10/26.
//

import Foundation
import Testing

@testable import libdawnUI

@MainActor
@Suite("WorkspaceActivityTextFormatterTests")
struct WorkspaceActivityTextFormatterTests {
    @Test("formats activity shorter than one hour")
    func formatsMinutes() {
        let formatter = WorkspaceActivityTextFormatter()
        let start = Date(timeIntervalSince1970: 0)
        let now = Date(timeIntervalSince1970: 25 * 60)

        #expect(
            formatter.activeText(since: start, relativeTo: now)
                == "25min in use"
        )
    }

    @Test("formats activity containing hours")
    func formatsHoursAndMinutes() {
        let formatter = WorkspaceActivityTextFormatter()
        let start = Date(timeIntervalSince1970: 0)
        let now = Date(timeIntervalSince1970: (5 * 60 + 12) * 60)

        #expect(
            formatter.activeText(since: start, relativeTo: now)
                == "5h 12min in use"
        )
    }

    @Test("future start dates do not produce negative durations")
    func clampsNegativeDuration() {
        let formatter = WorkspaceActivityTextFormatter()
        let start = Date(timeIntervalSince1970: 100)
        let now = Date(timeIntervalSince1970: 0)

        #expect(
            formatter.activeText(since: start, relativeTo: now)
                == "just now"
        )
    }

    @Test("formats the last-used date relative to now")
    func formatsLastUsedDate() {
        let formatter = WorkspaceActivityTextFormatter(
            locale: Locale(identifier: "en_US")
        )

        let now = Date(timeIntervalSince1970: 1_000)
        let lastUsed = now.addingTimeInterval(-5 * 60)

        #expect(
            formatter.lastUsedText(
                at: lastUsed,
                relativeTo: now
            ) == "5 minutes ago"
        )
    }

    @Test("formats sidebar activity for active and inactive workspaces")
    func formatsSidebarActivityText() {
        let formatter = WorkspaceActivityTextFormatter(
            locale: Locale(identifier: "en_US")
        )
        let now = Date(timeIntervalSince1970: 1_000)
        let started = now.addingTimeInterval(-25 * 60)
        let lastUsed = now.addingTimeInterval(-5 * 60)

        #expect(
            formatter.sidebarActivityText(
                isActive: true,
                activeSince: started,
                lastUsedAt: nil,
                relativeTo: now
            ) == "25min in use"
        )

        #expect(
            formatter.sidebarActivityText(
                isActive: false,
                activeSince: nil,
                lastUsedAt: lastUsed,
                relativeTo: now
            ) == "Last use 5 minutes ago"
        )

        #expect(
            formatter.sidebarActivityText(
                isActive: false,
                activeSince: nil,
                lastUsedAt: nil,
                relativeTo: now
            ) == "Never activated"
        )
    }
}
