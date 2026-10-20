//
//  MenuBarController.swift
//  dawn
//
//  Created by Rafael Venetikides on 15/10/26.
//

import AppKit
import SwiftUI

@MainActor
protocol MenuBarControlling: AnyObject {
    func stop()
}

@MainActor
final class MenuBarController: NSObject, MenuBarControlling {
    private let statusBar: NSStatusBar
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    private var isStopped = false

    init(
        workspace: WorkspaceRuntime,
        statusBar: NSStatusBar = .system
    ) {
        self.statusBar = statusBar
        self.statusItem = statusBar.statusItem(
            withLength: NSStatusItem.squareLength
        )
        self.popover = NSPopover()

        super.init()

        configureStatusItem()
        configurePopover(workspace: workspace)
    }

    func stop() {
        guard !isStopped else {
            return
        }

        isStopped = true

        popover.close()
        popover.contentViewController = nil

        statusItem.button?.target = nil
        statusItem.button?.action = nil

        statusBar.removeStatusItem(statusItem)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        let image = NSImage(
            systemSymbolName: "sunrise.fill",
            accessibilityDescription: "DAWN"
        )

        image?.isTemplate = true

        button.image = image
        button.toolTip = "DAWN"
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    private func configurePopover(
        workspace: WorkspaceRuntime
    ) {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(
            width: 320,
            height: 360
        )

        popover.contentViewController = NSHostingController(
            rootView: MenuBarRootView(
                workspace: workspace
            )
        )
    }

    @objc
    private func togglePopover(
        _ sender: NSStatusBarButton
    ) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        popover.show(
            relativeTo: sender.bounds,
            of: sender,
            preferredEdge: .minY
        )

        NSApp.activate()
    }
}
