//
//  ContextCreationApplication.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

import AppKit
import Foundation

struct ContextCreationApplication: Identifiable {
    let id: UUID
    let name: String
    let icon: NSImage

    init(id: UUID = UUID(), name: String, icon: NSImage) {
        self.id = id
        self.name = name
        self.icon = icon
    }
}
