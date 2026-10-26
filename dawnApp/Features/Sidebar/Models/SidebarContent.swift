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
    var update: AppUpdateAvailability?
    var errorMessage: String?
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
