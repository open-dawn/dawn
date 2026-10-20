import Foundation
import libdawn

enum SidebarDestination: Hashable {
    case context(UUID) // UUID represents the target context
    case settings
    case about

    var contextID: UUID? {
        switch self {
        case let .context(id): id
        case .settings, .about: nil
        }
    }

    func reconciled(with contexts: [WorkspaceContext]) -> SidebarDestination? {
        guard let contextID else {
            return self
        }

        return contexts.contains { $0.id == contextID } ? self : nil
    }
}
