import Foundation

enum SidebarDestination: Hashable, CaseIterable, Identifiable {
    case profiles
    case settings
    case about

    static let initial: SidebarDestination = .profiles

    var id: SidebarDestination {
        self
    }

    var title: String {
        switch self {
        case .profiles: "Profiles"
        case .settings: "Settings"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .profiles: "rectangle.stack"
        case .settings: "gearshape"
        case .about: "info.circle"
        }
    }
}
