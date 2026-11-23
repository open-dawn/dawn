import Foundation
import libdawn

struct SidebarContent {
    var workspaces: [Workspace] = []
    var archivedWorkspaces: [Workspace] = []
    var activity: WorkspaceActivityState = .empty
    var busyWorkspaceID: UUID?
    var isLoading = false
    var isAgentRunning = true
    var needsAccessibilityPermission = false
    var interactionsDisabled = false
    /// Newest error first (FILO). Cap enforced by the shell when pushing.
    var errorMessages: [SidebarErrorMessage] = []

    var activeWorkspaceID: UUID? {
        activity.activeWorkspaceID
    }
}

struct SidebarErrorMessage: Identifiable, Equatable {
    let id: UUID
    let text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

struct SidebarSearchState: Equatable {
    var text = ""
    var isPresented = false
    var isArchivedSectionExpanded = false
}

struct SidebarRowState: Equatable {
    var isSelected = false
    var isActive = false
    var isLoading = false
    var isEnabled = true
    var activityText = "Never activated"
}
