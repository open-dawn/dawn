//
//  ContextOpeningBehavior+WorkspaceTransition.swift
//  dawn
//
//  Created by Longhi on 06/11/26.
//

import libdawn
import libdawnUI

extension ContextOpeningBehavior {
    var activationPolicy: WorkspaceActivationPolicy {
        switch self {
        case .onlyOpen:
            .merge
        case .hideOthers:
            .hide
        case .closeOthers:
            .close
        }
    }

    var transition: WorkspaceTransition {
        WorkspaceTransition(activationPolicy: activationPolicy)
    }
}
