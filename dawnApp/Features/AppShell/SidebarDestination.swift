import Foundation
import libdawn

enum SidebarDestination: Hashable {
    case workspace(UUID)
    case settings
    case about
    #if DEBUG
    case debug
    #endif

    var workspaceID: UUID? {
        switch self {
        case let .workspace(id): id
        case .settings, .about:
            nil
        #if DEBUG
        case .debug:
            nil
        #endif
        }
    }

    func reconciled(with workspaces: [Workspace]) -> SidebarDestination? {
        guard let workspaceID else {
            return self
        }

        return workspaces.contains { $0.id == workspaceID } ? self : nil
    }
}
