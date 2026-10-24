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
    private var isClosing = false
    private let appOpener: any DawnAppOpening

    private var isStopped = false

    init(
        workspace: WorkspaceRuntime,
        statusBar: NSStatusBar = .system,
        appOpener: any DawnAppOpening = DawnAppOpener()
    ) {
        self.statusBar = statusBar
        self.statusItem = statusBar.statusItem(
            withLength: NSStatusItem.squareLength
        )
        self.popover = NSPopover()
        self.appOpener = appOpener

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
        button.action = #selector(handleStatusItemInteraction(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc
    private func handleStatusItemInteraction(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
        let isControlClick = event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true

        if isRightClick || isControlClick {
            showContextMenu(relativeTo: sender)
        } else {
            togglePopover(sender)
        }
    }

    private func configurePopover(
        workspace: WorkspaceRuntime
    ) {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        popover.contentViewController = NSHostingController(
            rootView: MenuBarRootView(
                workspace: workspace,
                openApp: { [weak self] route in
                    guard let self else {
                        return
                    }

                    try await appOpener.open(route)
                    closePopover()
                }
            )
        )
    }

    private func synchronizePopoverContentSize() {
        guard let contentView = popover.contentViewController?.view else {
            return
        }

        contentView.needsLayout = true
        contentView.layoutSubtreeIfNeeded()

        let fittingSize = contentView.fittingSize

        guard fittingSize.height > 0 else {
            return
        }

        popover.contentSize = NSSize(
            width: 320,
            height: ceil(fittingSize.height)
        )
    }

    @objc
    private func togglePopover(
        _ sender: NSStatusBarButton
    ) {
        guard !popover.isShown else {
            popover.contentViewController?.view.window?.makeFirstResponder(nil)

            closePopover()
            return
        }

        guard !isClosing else {
            return
        }

        NSApp.activate()
        synchronizePopoverContentSize()

        popover.show(
            relativeTo: sender.bounds,
            of: sender,
            preferredEdge: .minY
        )

        popover.contentViewController?.view.window?.makeKey()
    }

    private func closePopover(_ sender: Any? = nil) {
        guard popover.isShown else {
            return
        }

        popover.contentViewController?.view.window?.makeFirstResponder(nil)

        popover.performClose(sender)
    }

    private lazy var contextMenu: NSMenu = {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let openAppItem = NSMenuItem(
            title: "Open DAWN",
            action: #selector(openDawnApp),
            keyEquivalent: ""
        )
        openAppItem.target = self
        openAppItem.isEnabled = true

        let quitItem = NSMenuItem(
            title: "Quit DAWN Agent...",
            action: #selector(confirmQuit),
            keyEquivalent: ""
        )
        quitItem.target = self
        quitItem.isEnabled = true

        menu.addItem(openAppItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)

        return menu
    }()

    @objc
    private func openDawnApp() {
        Task {
            do {
                try await appOpener.open(.application)
            } catch {
                presentOpenAppError(error)
            }
        }
    }

    private func presentOpenAppError(_ error: Error) {
        NSApp.activate()

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn't Open DAWN"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showContextMenu(relativeTo sender: NSStatusBarButton) {
        if popover.isShown {
            popover.contentViewController?.view.window?.makeFirstResponder(nil)

            closePopover()
        }

        sender.highlight(true)

        contextMenu.popUp(
            positioning: nil,
            at: NSPoint(
                x: sender.bounds.minX,
                y: sender.bounds.minY
            ),
            in: sender
        )

        sender.highlight(false)
    }

    @objc
    private func confirmQuit() {
        NSApp.activate()

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Quit DAWN Agent?"
        alert.informativeText = """
        DAWN will stop managing your workspaces and its menu bar item will disappear. \
        Because DAWN Agent is a login item, it will start again the next time you sign in.
        """

        let quitButton = alert.addButton(withTitle: "Quit")
        quitButton.hasDestructiveAction = true

        let cancelButton = alert.addButton(withTitle: "Cancel")
        cancelButton.keyEquivalent = "\u{1b}"

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        NSApp.terminate(nil)
    }
}

extension MenuBarController: NSPopoverDelegate {
    func popoverWillClose(_ notification: Notification) {
        isClosing = true
    }

    func popoverDidClose(_ notification: Notification) {
        isClosing = false
    }
}
