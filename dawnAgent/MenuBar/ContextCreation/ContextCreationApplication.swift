//
//  ContextCreationApplication.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

import AppKit
import libdawn

struct ContextCreationApplication: Identifiable {
    let application: WorkspaceApplication
    let icon: NSImage

    var id: UUID {
        application.id
    }

    var name: String {
        application.displayName
    }
}
