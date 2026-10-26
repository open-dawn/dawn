import Foundation

public enum ActivationPolicy: String, Codable, Sendable, Equatable {
    case hide
    case merge
    case close
}

public struct WorkspaceTransition: Codable, Sendable, Equatable {
    public var activationPolicy: ActivationPolicy
    public var terminalCommand: String?

    public static let `default` = WorkspaceTransition()

    public init(
        activationPolicy: ActivationPolicy = .hide,
        terminalCommand: String? = nil
    ) {
        self.activationPolicy = activationPolicy
        self.terminalCommand = terminalCommand
    }
}