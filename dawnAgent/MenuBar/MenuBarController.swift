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
    private let appOpener: any DawnAppOpening
    private var panel: MenuBarPanel?
    private var hostingController: NSHostingController<MenuBarRootView>?

    private var isStopped = false
    private var isPanelPresented = false

    init(
        workspace: WorkspaceRuntime,
        statusBar: NSStatusBar = .system,
        appOpener: any DawnAppOpening = DawnAppOpener()
    ) {
        self.statusBar = statusBar
        self.statusItem = statusBar.statusItem(
            withLength: NSStatusItem.squareLength
        )
        self.appOpener = appOpener

        super.init()

        configureStatusItem()
        configurePanel(workspace: workspace)
    }

    func stop() {
        guard !isStopped else {
            return
        }

        isStopped = true

        closePanel()

        panel?.delegate = nil
        panel?.contentViewController = nil
        panel = nil
        hostingController = nil

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
            togglePanel(sender)
        }
    }

    private func configurePanel(
        workspace: WorkspaceRuntime
    ) {
        let hostingController = NSHostingController(
            rootView: MenuBarRootView(
                workspace: workspace,
                openApp: { [weak self] route in
                    guard let self else {
                        return
                    }

                    try await appOpener.open(route)
                    closePanel()
                }
            )
        )

        hostingController.view.wantsLayer = true
        hostingController.view.layer?.cornerRadius = 16
        hostingController.view.layer?.cornerCurve = .continuous
        hostingController.view.layer?.masksToBounds = true

        let panel = MenuBarPanel(contentViewController: hostingController)

        panel.delegate = self

        self.hostingController = hostingController
        self.panel = panel
    }

    private func synchronizePanelContentSize() {
        guard let panel, let contentView = panel.contentViewController?.view else {
            return
        }

        contentView.needsLayout = true
        contentView.layoutSubtreeIfNeeded()

        let fittingSize = contentView.fittingSize

        guard fittingSize.height > 0 else {
            return
        }

        panel.setContentSize(
            NSSize(
                width: 320,
                height: ceil(fittingSize.height)
            )
        )

        panel.invalidateShadow()
    }

    private func positionPanel(relativeTo button: NSStatusBarButton) {
        guard let panel, let buttonWindow = button.window, let visibleFrame = buttonWindow.screen?.visibleFrame else {
            return
        }

        let buttonRectInWindow = button.convert(button.bounds, to: nil)

        let buttonRectOnScreen = buttonWindow.convertToScreen(buttonRectInWindow)

        let horizontalMargin: CGFloat = 8
        let verticalSpacing: CGFloat = 4

        var originX = buttonRectOnScreen.midX - panel.frame.width / 2

        originX = min(
            max(
                originX,
                visibleFrame.minX + horizontalMargin
            ),
            visibleFrame.maxX - panel.frame.width - horizontalMargin
        )

        let originY = buttonRectOnScreen.minY - panel.frame.height - verticalSpacing

        panel.setFrameOrigin(
            NSPoint(x: round(originX), y: round(originY))
        )
    }

    @objc
    private func togglePanel(
        _ sender: NSStatusBarButton
    ) {
        guard let panel else {
            return
        }

        if isPanelPresented {
            closePanel()
            return
        }

        synchronizePanelContentSize()
        positionPanel(relativeTo: sender)

        sender.highlight(true)

        panel.orderFrontRegardless()
        panel.makeKey()

        isPanelPresented = true
    }

    private func closePanel() {
        guard let panel else {
            return
        }

        panel.makeFirstResponder(nil)
        panel.orderOut(nil)

        isPanelPresented = false
        statusItem.button?.highlight(false)
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
        closePanel()

        sender.highlight(true)
        defer {
            sender.highlight(false)
        }

        contextMenu.popUp(
            positioning: nil,
            at: NSPoint(
                x: sender.bounds.minX,
                y: sender.bounds.minY
            ),
            in: sender
        )
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

extension MenuBarController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        guard let panel,
              let window = notification.object as? NSWindow,
              window === panel, isPanelPresented
        else {
            return
        }

        guard panel.attachedSheet == nil else {
            return
        }

        closePanel()
    }
}
