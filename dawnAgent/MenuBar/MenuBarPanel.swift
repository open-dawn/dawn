//
//  MenuBarPanel.swift
//  dawn
//
//  Created by Rafael Venetikides on 27/10/26.
//

import AppKit

@MainActor
final class MenuBarPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    init(contentViewController: NSViewController) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.contentViewController = contentViewController

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu

        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        isFloatingPanel = true

        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient
        ]
    }
}
