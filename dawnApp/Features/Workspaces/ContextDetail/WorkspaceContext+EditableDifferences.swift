//
//  WorkspaceContext+EditableDifferences.swift
//  dawn
//
//  Created by Rafael Venetikides on 09/11/26.
//

import libdawn

extension WorkspaceContext {
    func editableContentDiffers(from other: WorkspaceContext) -> Bool {
        name != other.name
        || symbol != other.symbol
        || transition.activationPolicy != other.transition.activationPolicy
        || applications != other.applications
    }
}
