public enum Event: Codable, Sendable, Equatable {
    case debugPing(DebugPingEvent)
    case debugPong(DebugPongEvent)

    case initialized(InitializedEvent)

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

    case getAccessibilityStatus(GetAccessibilityStatusEvent)
    case promptAccessibilityTrust(PromptAccessibilityTrustEvent)
    case accessibilityStatus(AccessibilityStatusEvent)

    case getSettings(GetSettingsEvent)
    case settingsFetched(SettingsFetchedEvent)
    case availableSettings(AvailableSettingsEvent)

    case updateSettings(UpdateSettingsEvent)
    case settingsMutationAcknowledgement(SettingsMutationAcknowledgement)
    case applySettings(ApplySettingsEvent)

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
        }
    }
}
