//
//  WorkspaceCreationConfirmationView+Previews.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/10/26.
//

#if DEBUG

import Foundation
import SwiftUI

private struct WorkspaceCreationConfirmationPreview: View {
    var body: some View {
        VStack(spacing: 24) {
            DawnBrand(style: .compact)

            WorkspaceCreationConfirmationView(
                name: "Close everything",
                symbolName: "cup.and.saucer.fill",
                applications: previewApplications,
                activationPolicy: .close,
                onFinishAndSwitch: {},
                onFinish: {}
            )
        }
        .padding(16)
        .frame(width: 320, height: 600)
        .background(DawnColors.primaryBackground)
    }

    private var previewApplications: [WorkspaceCreationApplication] {
        [
            WorkspaceCreationApplication(
                bundleIdentifier: "com.apple.iCal",
                displayName: "Calendar",
                applicationURL: URL(fileURLWithPath: "/System/Applications/Calendar.app")
            ),
            WorkspaceCreationApplication(
                bundleIdentifier: "com.apple.Notes",
                displayName: "Notes",
                applicationURL: URL(fileURLWithPath: "/System/Applications/Notes.app")
            ),
            WorkspaceCreationApplication(
                bundleIdentifier: "com.apple.Music",
                displayName: "Music",
                applicationURL: URL(fileURLWithPath: "/System/Applications/Music.app")
            ),
            WorkspaceCreationApplication(
                bundleIdentifier: "com.apple.finder",
                displayName: "Finder",
                applicationURL: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
            )
        ]
    }
}

#Preview("Creation confirmation - Light") {
    WorkspaceCreationConfirmationPreview()
        .preferredColorScheme(.light)
}

#Preview("Creation confirmation - Dark") {
    WorkspaceCreationConfirmationPreview()
        .preferredColorScheme(.dark)
}

#endif
