//
//  WorkspaceCreationDraft.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

import Foundation
import libdawn

struct WorkspaceCreationDraft {
    var name = ""
    var symbolName: String?
    var selectedApplications: [WorkspaceCreationApplication] = []
    var activationPolicy: WorkspaceActivationPolicy = .hide
}
