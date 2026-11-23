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
        workspaces: [Workspace],
        activity: WorkspaceActivityState = .empty
    ) {
        let workspaceProvider = PreviewWorkspaceProvider(
            workspaces: workspaces,
            workspaceActivity: activity
        )

        _workspace = State(
            initialValue: WorkspaceRuntime(
                workspaceCatalog: workspaceProvider,
                workspaceSwitching: PreviewWorkspaceSwitcher()
            )
        )
    }

    var body: some View {
        MenuBarRootView(
            workspace: workspace,
            openApp: { _ in },
            modalPresentationState: MenuBarModalPresentationState()
        )
            .background(.regularMaterial)
            .preferredColorScheme(.dark)
            .task {
                await workspace.refresh()
            }
    }
}

@MainActor
private final class PreviewWorkspaceProvider: WorkspaceManaging {
    private var workspaces: [Workspace]
    var workspaceActivity: WorkspaceActivityState

    init(
        workspaces: [Workspace],
        workspaceActivity: WorkspaceActivityState = .empty
    ) {
        self.workspaces = workspaces
        self.workspaceActivity = workspaceActivity
    }

    func getAvailableWorkspaces() async -> [Workspace] {
        workspaces
    }

    func getWorkspaceActivity() async -> libdawn.WorkspaceActivityState {
        workspaceActivity
    }

    func getWorkspaceSnapshot() async -> WorkspaceSnapshot {
        return WorkspaceSnapshot(
            workspaces: workspaces,
            activity: workspaceActivity
        )
    }

    func recordWorkspaceActivation(workspaceID: UUID, at date: Date) async throws -> WorkspaceActivityState {
        guard workspaces.contains(where: { $0.id == workspaceID }) else {
            throw SettingsStoreError.workspaceNotFound(workspaceID)
        }

        workspaceActivity.activate(
            workspaceID: workspaceID,
            at: date
        )

        return workspaceActivity
    }

    func stopActiveWorkspace(at date: Date) async throws -> WorkspaceActivityState {
        workspaceActivity.stop(at: date)
        return workspaceActivity
    }

    func getWorkspace(id: UUID) async -> Workspace? {
        workspaces.first {
            $0.id == id
        }
    }

    func createWorkspace(
        name: String,
        symbol: String,
        applications: [WorkspaceApplication],
        transition: WorkspaceTransition
    ) async throws -> Workspace {
        let workspace = Workspace(
            name: name,
            symbol: symbol,
            applications: applications,
            transition: transition
        )

        workspaces.append(workspace)
        return workspace
    }

    func updateWorkspace(
        _ workspace: Workspace
    ) async throws {
        guard let index = workspaces.firstIndex(
            where: { $0.id == workspace.id }
        ) else {
            return
        }

        workspaces[index] = workspace
    }

    func deleteWorkspace(id: UUID) async throws {
        workspaceActivity.removeWorkspace(id: id)

        workspaces.removeAll {
            $0.id == id
        }
    }

    func archiveWorkspace(id: UUID) async throws {
        guard let index = workspaces.firstIndex(where: { $0.id == id }) else {
            return
        }

        workspaces[index].isArchived = true
        workspaceActivity.clearActiveSession(for: id)
    }

    func unarchiveWorkspace(id: UUID) async throws {
        guard let index = workspaces.firstIndex(where: { $0.id == id }) else {
            return
        }

        workspaces[index].isArchived = false
    }
}

@MainActor
private struct PreviewWorkspaceSwitcher: WorkspaceSwitching {
    func switchToWorkspace(
        to workspace: Workspace
    ) async throws {
    }
}

private enum MenuBarRootPreviewFixtures {
    static let workspaces = [
        Workspace(
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
        Workspace(
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
        Workspace(
            name: "Gaming",
            symbol: "briefcase.fill",
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

        let work = workspaces[0]
        let personal = workspaces[1]

        activity.activate(
            workspaceID: personal.id,
            at: now.addingTimeInterval(-2 * 24 * 60 * 60)
        )

        activity.stop(
            at: now.addingTimeInterval(-24 * 60 * 60)
        )

        activity.activate(
            workspaceID: work.id,
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
        workspaces: MenuBarRootPreviewFixtures.workspaces,
        activity: MenuBarRootPreviewFixtures.activity(
            relativeTo: now
        )
    )
}

#Preview("Root — Inactive Workspaces") {
    MenuBarRootPreview(
        workspaces: MenuBarRootPreviewFixtures.workspaces
    )
}

#Preview("Root — Empty") {
    MenuBarRootPreview(workspaces: [])
}

#endif
