import Foundation

struct Context: Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let apps: [String]

    init(name: String, icon: String, apps: [String]) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.apps = apps
    }
}

extension Context {
    static func preview(_ index: Int) -> Context {
        Context(
            name: "New Context \(index)",
            icon: "gear",
            apps: [ "VSCode", "Helium", "NaN" ]
        )
    }

    static func samples(_ length: Int = 8) -> [Context] {
        guard (length > 0) else { return [] }
        return (0 ..< length).map { i in Context.preview(i) }
    }
}
