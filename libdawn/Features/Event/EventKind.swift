public enum EventKind: String, Codable, Sendable, Hashable, CaseIterable {
    case debugPing
    case debugPong

    case initialized

    // MARK: Contexts
    case getContexts
    case contextsFetched
    case switchContext
    case createContext
    case updateContext
    case deleteContext
    case archiveContext
    case unarchiveContext

    case availableContexts
    case contextMutationAcknowledged

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
}
