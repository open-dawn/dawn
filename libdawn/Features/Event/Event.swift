public enum Event: Codable, Sendable, Equatable {
    // MARK: Debug
    case debugPing(DebugPingEvent)
    case debugPong(DebugPongEvent)

    // MARK: Initialize
    case initialized(InitializedEvent)

    // MARK: Workspace
    case getWorkspaces(GetWorkspacesEvent)
    case workspacesFetched(WorkspacesFetchedEvent)
    case switchWorkspace(SwitchWorkspaceEvent)
    case createWorkspace(CreateWorkspaceEvent)
    case updateWorkspace(UpdateWorkspaceEvent)
    case deleteWorkspace(DeleteWorkspaceEvent)
    case archiveWorkspace(ArchiveWorkspaceEvent)
    case unarchiveWorkspace(UnarchiveWorkspaceEvent)
    case stopWorkspace(StopWorkspaceEvent)

    case availableWorkspaces(AvailableWorkspacesEvent)
    case workspaceMutationAcknowledged(WorkspaceMutationAcknowledgement)

    // MARK: Accessibility
    case getAccessibilityStatus(GetAccessibilityStatusEvent)
    case promptAccessibilityTrust(PromptAccessibilityTrustEvent)
    case accessibilityStatus(AccessibilityStatusEvent)

    // MARK: Settings
    case getSettings(GetSettingsEvent)
    case settingsFetched(SettingsFetchedEvent)
    case availableSettings(AvailableSettingsEvent)

    case updateSettings(UpdateSettingsEvent)
    case settingsMutationAcknowledgement(SettingsMutationAcknowledgement)
    case applySettings(ApplySettingsEvent)

    // MARK: Update
    case getComponentIdentity(GetComponentIdentityEvent)
    case componentIdentity(ComponentIdentityEvent)
    case prepareForApplicationUpdate(PrepareForApplicationUpdateEvent)
    case applicationUpdatePreparationAcknowledged(ApplicationUpdatePrepAcknowledgement)
    case cancelApplicationUpdatePreparation(CancelApplicationUpdatePreparationEvent)
    case applicationUpdatePreparationCancelled(ApplicationUpdatePrepCancelledEvent)

    public var kind: EventKind {
        switch self {
        case .debugPing: .debugPing
        case .debugPong: .debugPong
        case .initialized: .initialized
        case .getWorkspaces: .getWorkspaces
        case .workspacesFetched: .workspacesFetched
        case .createWorkspace: .createWorkspace
        case .updateWorkspace: .updateWorkspace
        case .deleteWorkspace: .deleteWorkspace
        case .archiveWorkspace: .archiveWorkspace
        case .unarchiveWorkspace: .unarchiveWorkspace
        case .switchWorkspace: .switchWorkspace
        case .stopWorkspace: .stopWorkspace
        case .workspaceMutationAcknowledged: .workspaceMutationAcknowledged
        case .availableWorkspaces: .availableWorkspaces
        case .getAccessibilityStatus: .getAccessibilityStatus
        case .promptAccessibilityTrust: .promptAccessibilityTrust
        case .accessibilityStatus: .accessibilityStatus
        case .getSettings: .getSettings
        case .settingsFetched: .settingsFetched
        case .availableSettings: .availableSettings
        case .updateSettings: .updateSettings
        case .settingsMutationAcknowledgement: .settingsMutationAcknowledgement
        case .applySettings: .applySettings
        case .getComponentIdentity: .getComponentIdentity
        case .componentIdentity: .componentIdentity
        case .prepareForApplicationUpdate: .prepareForApplicationUpdate
        case .applicationUpdatePreparationAcknowledged: .applicationUpdatePreparationAcknowledged
        case .cancelApplicationUpdatePreparation: .cancelApplicationUpdatePreparation
        case .applicationUpdatePreparationCancelled: .applicationUpdatePreparationCancelled
        }
    }
}
