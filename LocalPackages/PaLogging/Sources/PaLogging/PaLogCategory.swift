//
//  PaLogCategory.swift
//  PaLogging
//
//  Created by Rafael Venetikides on 04/09/26.
//

public enum PaLogCategory: String, Sendable {
    case general
    case appLifecycle = "app-lifecycle"
    case settings
    case userInterface = "user-interface"
    case eventBus = "event-bus"
    case transport
}