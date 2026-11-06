//
//  ContextOpeningBehavior+WorkspaceTransition.swift
//  dawn
//

import libdawn

extension ContextOpeningBehavior {
    public var activationPolicy: WorkspaceActivationPolicy {
        switch self {
        case .onlyOpen:
            .merge
        case .hideOthers:
            .hide
        case .closeOthers:
            .close
        }
    }

    public var transition: WorkspaceTransition {
        WorkspaceTransition(activationPolicy: activationPolicy)
    }
}
