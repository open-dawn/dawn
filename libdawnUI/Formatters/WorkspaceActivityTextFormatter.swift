//
//  WorkspaceActivityTextFormatter.swift
//  dawn
//
//  Created by Rafael Venetikides on 26/10/26.
//

import Foundation

public struct WorkspaceActivityTextFormatter: Sendable {
    private let locale: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
    }

    public func activeText(since startDate: Date, relativeTo now: Date) -> String {
        let interval = max(now.timeIntervalSince(startDate), 0)
        let totalMinutes = Int(interval / 60)

        guard totalMinutes > 0 else {
            return "just now"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)min in use"
        }

        return "\(minutes)min in use"
    }

    public func lastUsedText(at date: Date, relativeTo now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()

        formatter.locale = locale
        formatter.unitsStyle = .full

        return formatter.localizedString(
            for: date,
            relativeTo: now
        )
    }
}
