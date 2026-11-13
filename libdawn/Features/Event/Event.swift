public enum Event: Codable, Sendable, Equatable {
    // MARK: Debug
    case debugPing(DebugPingEvent)
    case debugPong(DebugPongEvent)

    // MARK: Initialize
    case initialized(InitializedEvent)

    // MARK: Context
    case getContexts(GetContextsEvent)
    case contextsFetched(ContextsFetchedEvent)
    case switchContext(SwitchContextEvent)
    case createContext(CreateContextEvent)
    case updateContext(UpdateContextEvent)
    case deleteContext(DeleteContextEvent)
    case archiveContext(ArchiveContextEvent)
    case unarchiveContext(UnarchiveContextEvent)
    case stopContext(StopContextEvent)

    case availableContexts(AvailableContextsEvent)
    case contextMutationAcknowledged(ContextMutationAcknowledgement)

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
        case .getContexts: .getContexts
        case .contextsFetched: .contextsFetched
        case .createContext: .createContext
        case .updateContext: .updateContext
        case .deleteContext: .deleteContext
        case .archiveContext: .archiveContext
        case .unarchiveContext: .unarchiveContext
        case .switchContext: .switchContext
        case .stopContext: .stopContext
        case .contextMutationAcknowledged: .contextMutationAcknowledged
        case .availableContexts: .availableContexts
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
