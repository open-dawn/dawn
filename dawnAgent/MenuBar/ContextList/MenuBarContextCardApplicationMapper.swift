//
//  MenuBarContextCardApplicationMapper.swift
//  dawn
//
//  Created by Rafael Venetikides on 27/10/26.
//

import AppKit
import libdawn
import libdawnUI

enum MenuBarContextCardApplicationMapper {
    static func makeModel(for application: WorkspaceApplication) -> ContextCardModel.Application {
        let applicationURL =
            application.applicationURL
            ?? NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: application
                    .bundleIdentifier
            )

        let icon =
            applicationURL.map {
                NSWorkspace.shared.icon(forFile: $0.path(percentEncoded: false))
            }
            ?? NSWorkspace.shared.icon(for: .application)

        return ContextCardModel.Application(
            id: application.id,
            name: application.displayName,
            icon: icon
        )
    }
}
