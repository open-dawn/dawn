import Foundation
struct ContextApp: Identifiable {
    var id: UUID
    var name: String

    init() {
        self.id = UUID()
        self.name = ""
    }

    init(_ name: String) {
        self.id = UUID()
        self.name = name
    }
}
