//
//  WorkspaceCard+Previews.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/10/26.
//

#if DEBUG

import SwiftUI
import AppKit

private func previewApplication(
    name: String,
    symbolName: String
) -> WorkspaceCardModel.Application {
    let icon =
        NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: name
        ) ?? NSImage(size: NSSize(width: 18, height: 18))

    return WorkspaceCardModel.Application(
        name: name,
        icon: icon
    )
}

#Preview("Workspace Card States") {
    VStack(spacing: 12) {
        WorkspaceCard(
            model: WorkspaceCardModel(
                name: "Apple Developer Academy",
                symbolName: "house.fill",
                status: .active(
                    activityText: "5h 12min in use"
                )
            )
        )

        WorkspaceCard(
            model: WorkspaceCardModel(
                name: "Study",
                symbolName: "book.closed",
                status: .inactive(
                    lastUsedText: "yesterday"
                ),
                applications: [
                    previewApplication(
                        name: "Safari",
                        symbolName: "safari"
                    ),
                    previewApplication(
                        name: "Notes",
                        symbolName: "note.text"
                    ),
                    previewApplication(
                        name: "Music",
                        symbolName: "music.note"
                    ),
                    previewApplication(
                        name: "Calendar",
                        symbolName: "calendar"
                    ),
                    previewApplication(
                        name: "Messages",
                        symbolName: "message"
                    ),
                ]
            )
        )

        WorkspaceCard(
            model: WorkspaceCardModel(
                name: "Work",
                symbolName: "briefcase.fill",
                status: .inactive(
                    lastUsedText: nil
                )
            ),
            isLoading: true
        )
    }
    .padding(16)
    .frame(width: 320, height: 300)
    .background(.regularMaterial)
    .preferredColorScheme(.dark)
}

#endif
