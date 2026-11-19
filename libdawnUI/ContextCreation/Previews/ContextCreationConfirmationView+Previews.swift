//
//  ContextCreationConfirmationView+Previews.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/10/26.
//

#if DEBUG

import Foundation
import SwiftUI

private struct ContextCreationConfirmationPreview: View {
    var body: some View {
        VStack(spacing: 24) {
            DawnBrand(style: .compact)

            ContextCreationConfirmationView(
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

    private var previewApplications: [ContextCreationApplication] {
        [
            ContextCreationApplication(
                bundleIdentifier: "com.apple.iCal",
                displayName: "Calendar",
                applicationURL: URL(fileURLWithPath: "/System/Applications/Calendar.app")
            ),
            ContextCreationApplication(
                bundleIdentifier: "com.apple.Notes",
                displayName: "Notes",
                applicationURL: URL(fileURLWithPath: "/System/Applications/Notes.app")
            ),
            ContextCreationApplication(
                bundleIdentifier: "com.apple.Music",
                displayName: "Music",
                applicationURL: URL(fileURLWithPath: "/System/Applications/Music.app")
            ),
            ContextCreationApplication(
                bundleIdentifier: "com.apple.finder",
                displayName: "Finder",
                applicationURL: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
            )
        ]
    }
}

#Preview("Creation confirmation - Light") {
    ContextCreationConfirmationPreview()
        .preferredColorScheme(.light)
}

#Preview("Creation confirmation - Dark") {
    ContextCreationConfirmationPreview()
        .preferredColorScheme(.dark)
}

#endif
