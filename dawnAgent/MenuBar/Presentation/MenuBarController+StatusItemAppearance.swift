//
//  MenuBarController+StatusItemAppearance.swift
//  dawn
//

import AppKit
import Observation
import libdawnUI

extension MenuBarController {
    func startObservingActiveWorkspace() {
        updateStatusItemAppearance()
        observeActiveWorkspace()
    }

    func updateStatusItemAppearance() {
        guard let button = statusItemButton else {
            return
        }

        button.image = makeStatusItemImage(isActive: hasActiveWorkspace)
    }

    func makeStatusItemImage(isActive: Bool) -> NSImage? {
        let accessibilityDescription =
            isActive
            ? "DAWN, workspace active"
            : "DAWN, no active workspace"

        let image =
            (DawnSymbol.nsImage(isActive: isActive)?.copy() as? NSImage)
            ?? NSImage(
                systemSymbolName: isActive ? "sunrise.fill" : "sunrise",
                accessibilityDescription: accessibilityDescription
            )

        guard let image else {
            return nil
        }

        let targetHeight: CGFloat = 12
        let aspectRatio = image.size.width / max(image.size.height, 1)

        image.size = NSSize(
            width: targetHeight * aspectRatio,
            height: targetHeight
        )
        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription

        return image
    }

    private func observeActiveWorkspace() {
        withObservationTracking {
            _ = observedActiveWorkspaceID
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.canUpdateStatusItemAppearance else {
                    return
                }

                self.updateStatusItemAppearance()
                self.observeActiveWorkspace()
            }
        }
    }
}
