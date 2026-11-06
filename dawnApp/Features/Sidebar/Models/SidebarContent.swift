import Foundation
import libdawn

struct SidebarContent {
    var contexts: [WorkspaceContext] = []
    var archivedContexts: [WorkspaceContext] = []
    var activeContextID: UUID?
    var busyContextID: UUID?
    var isLoading = false
    var isAgentRunning = true
    var needsAccessibilityPermission = false
    var interactionsDisabled = false
    /// Newest error first (FILO). Cap enforced by the shell when pushing.
    var errorMessages: [SidebarErrorMessage] = []
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
}
