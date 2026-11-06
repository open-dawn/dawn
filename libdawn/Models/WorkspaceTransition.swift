import Foundation

public struct WorkspaceTransition: Codable, Sendable, Equatable {
    public var activationPolicy: WorkspaceActivationPolicy
    public var terminalCommand: String?

    public static let `default` = WorkspaceTransition()

    public init(
        activationPolicy: WorkspaceActivationPolicy = .hide,
        terminalCommand: String? = nil
    ) {
        self.activationPolicy = activationPolicy
        self.terminalCommand = terminalCommand
    }
}
