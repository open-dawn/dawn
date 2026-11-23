public enum EventKind: String, Codable, Sendable, Hashable, CaseIterable {
    case debugPing
    case debugPong

    case initialized

    // MARK: Workspaces
    case getWorkspaces
    case workspacesFetched
    case switchWorkspace
    case createWorkspace
    case updateWorkspace
    case deleteWorkspace
    case archiveWorkspace
    case unarchiveWorkspace
    case stopWorkspace

    case availableWorkspaces
    case workspaceMutationAcknowledged

    // MARK: Accessibility
    case getAccessibilityStatus
    case promptAccessibilityTrust
    case accessibilityStatus

    // MARK: Settings
    case getSettings
    case settingsFetched
    case availableSettings

    case updateSettings
    case settingsMutationAcknowledgement
    case applySettings

    // MARK: Update
    case getComponentIdentity
    case componentIdentity
    case prepareForApplicationUpdate
    case applicationUpdatePreparationAcknowledged
    case cancelApplicationUpdatePreparation
    case applicationUpdatePreparationCancelled
}
