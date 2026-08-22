import Foundation
struct ContextApp: Identifiable, Equatable {
    var id: UUID
    var name: String

    init(_ name: String) {
        self.id = UUID()
        self.name = name
    }
}
