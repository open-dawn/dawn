import Foundation

struct Context: Identifiable {
    let id: UUID
    var name: String
    var icon: String
    var apps: [ContextApp]

    init() {
        self.id = UUID()
        self.name = ""
        self.icon = ""
        self.apps = [ContextApp]()
    }

    init(name: String, icon: String, apps: [ContextApp]) {
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
            apps: [ .init("VSCode"), .init("Helium"), .init("NaN") ]
        )
    }

    static func samples(_ count: Int = 8) -> [Context] {
        guard (count > 0) else { return [] }
        return (0 ..< count).map { i in Context.preview(i) }
    }
}
