//
//  ContextCreationDraft.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

import Foundation
import libdawn

struct ContextCreationDraft {
    var name = ""
    var symbolName: String?
    var selectedApplications: [ContextCreationApplication] = []
    var activationPolicy: WorkspaceActivationPolicy = .hide
}
