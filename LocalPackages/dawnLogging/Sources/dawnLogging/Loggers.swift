//
//  Loggers.swift
//  dawnLogging
//
//  Created by Rafael Venetikides on 04/09/26.
//

import OSLog

public enum Loggers {
    private static let subsystem =
        Bundle.main.bundleIdentifier
        ?? "app.opendawn"

    public static let general = Logger(
        subsystem: subsystem,
        category: LogCategory.general.rawValue
    )

    public static let appLifecycle = Logger(
        subsystem: subsystem,
        category: LogCategory.appLifecycle.rawValue
    )

    public static let settings = Logger(
        subsystem: subsystem,
        category: LogCategory.settings.rawValue
    )

    public static let userInterface = Logger(
        subsystem: subsystem,
        category: LogCategory.userInterface.rawValue
    )

    public static let eventBus = Logger(
        subsystem: subsystem,
        category: LogCategory.eventBus.rawValue
    )

    public static let transport = Logger(
        subsystem: subsystem,
        category: LogCategory.transport.rawValue
    )
}
