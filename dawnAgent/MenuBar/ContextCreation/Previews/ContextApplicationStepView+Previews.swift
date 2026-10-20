//
//  ContextApplicationStepView+Previews.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

#if DEBUG

import AppKit
import SwiftUI

private struct ContextApplicationsStepPreview: View {
    private let applications: [ContextCreationApplication]

    @State private var selectedApplicationIDs: [UUID]

    init() {
        let applications = [
            previewApplication(
                name: "Safari",
                bundleIdentifier: "com.apple.Safari"
            ),
            previewApplication(
                name: "Notes",
                bundleIdentifier: "com.apple.Notes"
            ),
            previewApplication(
                name: "Calendar",
                bundleIdentifier: "com.apple.iCal"
            ),
            previewApplication(
                name: "Music",
                bundleIdentifier: "com.apple.Music"
            ),
            previewApplication(
                name: "Messages",
                bundleIdentifier: "com.apple.MobileSMS"
            ),
            previewApplication(
                name: "Mail",
                bundleIdentifier: "com.apple.mail"
            ),
            previewApplication(
                name: "Terminal",
                bundleIdentifier: "com.apple.Terminal"
            ),
            previewApplication(
                name: "Xcode",
                bundleIdentifier: "com.apple.dt.Xcode"
            ),
        ]

        self.applications = applications
        _selectedApplicationIDs = State(
            initialValue:
                applications.prefix(2).map(\.id)
        )
    }

    var body: some View {
        ContextApplicationsStepView(
            applications: applications,
            selectedApplicationIDs: $selectedApplicationIDs,
            onChooseApplication: {},
            onNext: {}
        )
        .padding(16)
        .frame(width: 320)
        .background(.regularMaterial)
        .preferredColorScheme(.dark)
    }
}

@MainActor
private func previewApplication(
    name: String,
    bundleIdentifier: String
) -> ContextCreationApplication {
    let applicationURL = NSWorkspace.shared.urlForApplication(
        withBundleIdentifier: bundleIdentifier
    )

    let icon =
        applicationURL.map {
            NSWorkspace.shared.icon(forFile: $0.path)
        } ??
        NSImage(
            systemSymbolName: "app.fill",
            accessibilityDescription: name
        ) ??
        NSImage(size: NSSize(width: 43, height: 43))

    return ContextCreationApplication(
        name: name,
        icon: icon
    )
}

#Preview("Application selection") {
    ContextApplicationsStepPreview()
}

#endif