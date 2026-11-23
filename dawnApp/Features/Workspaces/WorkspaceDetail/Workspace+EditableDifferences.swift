//
//  Workspace+EditableDifferences.swift
//  dawn
//
//  Created by Rafael Venetikides on 09/11/26.
//

import libdawn

extension Workspace {
    func editableContentDiffers(from other: Workspace) -> Bool {
        name != other.name
        || symbol != other.symbol
        || transition.activationPolicy != other.transition.activationPolicy
        || transition.terminalCommand != other.transition.terminalCommand
        || applications != other.applications
    }

    mutating func mergeCleanFields(
        from snapshot: Workspace,
        committed: Workspace?
    ) {
        if name == committed?.name {
            name = snapshot.name
        }
        if symbol == committed?.symbol {
            symbol = snapshot.symbol
        }
        if transition.activationPolicy == committed?.transition.activationPolicy {
            transition.activationPolicy = snapshot.transition.activationPolicy
        }
        if transition.terminalCommand == committed?.transition.terminalCommand {
            transition.terminalCommand = snapshot.transition.terminalCommand
        }
        if applications == committed?.applications {
            applications = snapshot.applications
        }
    }

    mutating func alignCleanFields(
        with current: Workspace,
        snapshot: Workspace
    ) {
        if current.name == snapshot.name {
            name = snapshot.name
        }
        if current.symbol == snapshot.symbol {
            symbol = snapshot.symbol
        }
        if current.transition.activationPolicy == snapshot.transition.activationPolicy {
            transition.activationPolicy = snapshot.transition.activationPolicy
        }
        if current.transition.terminalCommand == snapshot.transition.terminalCommand {
            transition.terminalCommand = snapshot.transition.terminalCommand
        }
        if current.applications == snapshot.applications {
            applications = snapshot.applications
        }
    }
}
