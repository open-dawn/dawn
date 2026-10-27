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

    init(
        contexts: [WorkspaceContext],
        activity: WorkspaceActivityState = .empty
    ) {
        let contextProvider = PreviewContextProvider(
            contexts: contexts,
            workspaceActivity: activity
        )

        _workspace = State(
            initialValue: WorkspaceRuntime(
                contextManager: contextProvider,
                contextSwitching: PreviewContextSwitcher()
            )
        )
    }

    var body: some View {
        MenuBarRootView(
            workspace: workspace,
            openApp: { _ in }
        )
            .background(.regularMaterial)
            .preferredColorScheme(.dark)
            .task {
                await workspace.refresh()
            }
    }
}

@MainActor
private final class PreviewContextProvider: WorkspaceManaging {
    private var contexts: [WorkspaceContext]
    var workspaceActivity: WorkspaceActivityState

    init(
        contexts: [WorkspaceContext],
        workspaceActivity: WorkspaceActivityState = .empty
    ) {
        self.contexts = contexts
        self.workspaceActivity = workspaceActivity
    }

    func getAvailableContexts() async -> [WorkspaceContext] {
        contexts
    }

    func getWorkspaceActivity() async -> libdawn.WorkspaceActivityState {
        workspaceActivity
    }

    func getWorkspaceSnapshot() async -> WorkspaceSnapshot {
        return WorkspaceSnapshot(
            contexts: contexts,
            activity: workspaceActivity
        )
    }

    func recordContextActivation(contextID: UUID, at date: Date) async throws -> WorkspaceActivityState {
        guard contexts.contains(where: { $0.id == contextID }) else {
            throw SettingsStoreError.contextNotFound(contextID)
        }

        workspaceActivity.activate(
            contextID: contextID,
            at: date
        )

        return workspaceActivity
    }

    func stopActiveContext(at date: Date) async throws -> WorkspaceActivityState {
        workspaceActivity.stop(at: date)
        return workspaceActivity
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
        workspaceActivity.removeContext(id: id)

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

    static func activity(
        relativeTo now: Date
    ) -> WorkspaceActivityState {
        var activity = WorkspaceActivityState.empty

        let work = contexts[0]
        let personal = contexts[1]

        activity.activate(
            contextID: personal.id,
            at: now.addingTimeInterval(-2 * 24 * 60 * 60)
        )

        activity.stop(
            at: now.addingTimeInterval(-24 * 60 * 60)
        )

        activity.activate(
            contextID: work.id,
            at: now.addingTimeInterval(
                -(5 * 60 + 12) * 60
            )
        )

        return activity
    }
}

#Preview("Root — Activity States") {
    let now = Date.now

    MenuBarRootPreview(
        contexts: MenuBarRootPreviewFixtures.contexts,
        activity: MenuBarRootPreviewFixtures.activity(
            relativeTo: now
        )
    )
}

#Preview("Root — Inactive Contexts") {
    MenuBarRootPreview(
        contexts: MenuBarRootPreviewFixtures.contexts
    )
}

#Preview("Root — Empty") {
    MenuBarRootPreview(contexts: [])
}

#endif
