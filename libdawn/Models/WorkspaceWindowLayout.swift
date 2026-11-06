import Foundation

public enum WorkspaceWindowLayout: String, Codable, Sendable, Equatable, CaseIterable {
    case window
    case minimized
    case fullscreen
}
