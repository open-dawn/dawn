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
    case stopContext

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

    // MARK: Update
    case getComponentIdentity
    case componentIdentity
    case prepareForApplicationUpdate
    case applicationUpdatePreparationAcknowledged
    case cancelApplicationUpdatePreparation
    case applicationUpdatePreparationCancelled
}
