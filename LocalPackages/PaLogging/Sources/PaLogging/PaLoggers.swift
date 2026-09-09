//
//  PaLoggers.swift
//  PaLogging
//
//  Created by Rafael Venetikides on 04/09/26.
//

import OSLog

public enum PaLoggers {
    private static let subsystem =
        Bundle.main.bundleIdentifier
        ?? "dev.longhi.pineappleinc"

    public static let general = Logger(
        subsystem: subsystem,
        category: PaLogCategory.general.rawValue
    )

    public static let appLifecycle = Logger(
        subsystem: subsystem,
        category: PaLogCategory.appLifecycle.rawValue
    )

    public static let settings = Logger(
        subsystem: subsystem,
        category: PaLogCategory.settings.rawValue
    )

    public static let userInterface = Logger(
        subsystem: subsystem,
        category: PaLogCategory.userInterface.rawValue
    )

    public static let eventBus = Logger(
        subsystem: subsystem,
        category: PaLogCategory.eventBus.rawValue
    )

    public static let transport = Logger(
        subsystem: subsystem,
        category: PaLogCategory.transport.rawValue
    )
}
