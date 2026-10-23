import Foundation
import libdawn

enum SidebarDestination: Hashable {
    case context(UUID)
    case settings
    case about
    #if DEBUG
    case debug
    #endif

    var contextID: UUID? {
        switch self {
        case let .context(id): id
        case .settings, .about:
            nil
        #if DEBUG
        case .debug:
            nil
        #endif
        }
    }

    func reconciled(with contexts: [WorkspaceContext]) -> SidebarDestination? {
        guard let contextID else {
            return self
        }

        return contexts.contains { $0.id == contextID } ? self : nil
    }
}
