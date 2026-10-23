import Foundation

public enum ActivationPolicy: String, Codable, Sendable, Equatable {
    case hide
    case merge
    case close
}

public struct WorkspaceTransition: Codable, Sendable, Equatable {
    public var activationPolicy: ActivationPolicy
    public var setFocus: String?
    public var terminalCommand: String?

    public static let default = WorkspaceTransition()

    public init(
        activationPolicy: ActivationPolicy = .hide,
        setFocus: String? = nil,
        terminalCommand: String? = nil
    ) {
        self.activationPolicy = activationPolicy
        self.setFocus = setFocus
        self.terminalCommand = terminalCommand
    }
}
