//
//  MenuBarRootView+Previews.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/10/26.
//

#if DEBUG

import SwiftUI
import libdawn

@MainActor
private struct MenuBarRootPreview: View {
    @State private var workspace: WorkspaceRuntime

    init(contexts: [WorkspaceContext]) {
        let contextProvider = PreviewContextProvider(
            contexts: contexts
        )

        _workspace = State(
            initialValue: WorkspaceRuntime(
                contextManager: contextProvider,
                contextSwitching: PreviewContextSwitcher()
            )
        )
    }

    var body: some View {
        MenuBarRootView(workspace: workspace)
            .background(.regularMaterial)
            .preferredColorScheme(.dark)
            .task {
                await workspace.refresh()

                guard let firstContext = workspace.contexts.first else {
                    return
                }

                try? await workspace.activateContext(
                    id: firstContext.id
                )
            }
    }
}

@MainActor
private final class PreviewContextProvider: ContextProviding {
    private var contexts: [WorkspaceContext]

    init(contexts: [WorkspaceContext]) {
        self.contexts = contexts
    }

    func getAvailableContexts() async -> [WorkspaceContext] {
        contexts
    }

    func getContext(id: UUID) async -> WorkspaceContext? {
        contexts.first {
            $0.id == id
        }
    }

    func createContext(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication]
    ) async throws -> WorkspaceContext {
        let context = WorkspaceContext(
            name: name,
            symbol: symbol,
            applications: applications
        )

        contexts.append(context)
        return context
    }

    func updateContext(
        _ context: WorkspaceContext
    ) async throws {
        guard let index = contexts.firstIndex(
            where: { $0.id == context.id }
        ) else {
            return
        }

        contexts[index] = context
    }

    func deleteContext(id: UUID) async throws {
        contexts.removeAll {
            $0.id == id
        }
    }
}

@MainActor
private struct PreviewContextSwitcher: ContextSwitching {
    func switchToContext(
        to context: WorkspaceContext
    ) async throws {
    }
}

private enum MenuBarRootPreviewFixtures {
    static let contexts = [
        WorkspaceContext(
            name: "Work",
            symbol: "briefcase.fill",
            applications: [
                WorkspaceApplication(
                    bundleIdentifier: "com.apple.Safari",
                    displayName: "Safari"
                ),
                WorkspaceApplication(
                    bundleIdentifier: "com.apple.mail",
                    displayName: "Mail"
                ),
                WorkspaceApplication(
                    bundleIdentifier: "com.apple.iCal",
                    displayName: "Calendar"
                ),
            ]
        ),
        WorkspaceContext(
            name: "Personal",
            symbol: "person.fill",
            applications: [
                WorkspaceApplication(
                    bundleIdentifier: "com.apple.Notes",
                    displayName: "Notes"
                ),
                WorkspaceApplication(
                    bundleIdentifier: "com.apple.MobileSMS",
                    displayName: "Messages"
                ),
            ]
        ),
        WorkspaceContext(
            name: "Gaming",
            symbol: "gamecontroller.fill",
            applications: [
                WorkspaceApplication(
                    bundleIdentifier: "com.apple.Music",
                    displayName: "Music"
                ),
            ]
        ),
    ]
}

#Preview("Root — Contexts") {
    MenuBarRootPreview(
        contexts: MenuBarRootPreviewFixtures.contexts
    )
}

#Preview("Root — Empty") {
    MenuBarRootPreview(contexts: [])
}

#endif
