// CURSOR: NEED REVIEW
//
//  WorkspaceTransition.swift
//  dawn
//

import Foundation

/// How non-member apps are handled when entering a workspace.
public enum ActivationPolicy: String, Codable, Sendable, Equatable {
    /// Hide apps that are not part of the workspace (default).
    case hide
    /// Leave existing apps alone; only open missing workspace apps.
    case merge
    /// Attempt to quit apps that are not part of the workspace.
    case close
}

/// Side effects applied when switching into a workspace.
public struct WorkspaceTransition: Codable, Sendable, Equatable {
    public var activationPolicy: ActivationPolicy
    /// macOS Focus mode name to enable (e.g. "Do Not Disturb"), if possible.
    public var setFocus: String?
    /// Shell command to run after the switch, if possible.
    public var terminalCommand: String?

    public static let `default` = WorkspaceTransition()

    public init(
        activationPolicy: ActivationPolicy = .hide,
        setFocus: String? = nil,
        terminalCommand: String? = nil
    ) {
        self.activationPolicy = activationPolicy
        self.setFocus = setFocus
        self.terminalCommand = terminalCommand
    }
}
