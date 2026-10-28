public enum EventKind: String, Codable, Sendable, Hashable, CaseIterable {
    case debugPing
    case debugPong
    case initialized

    // MARK: Contexts
    case getContexts
    case contextsFetched
    case createContext
    case updateContext
    case deleteContext
    case switchContext
    case contextMutationAcknowledged
    case availableContexts

    // MARK: MenuBar Visibility
    case getMenuBarVisibility
    case setMenuBarVisibility
    case menuBarVisibilityState
    case menuBarVisibilityMutationAcknowledged

    // MARK: Settings
    case getSettings
    case settingsFetched
}
