import SwiftUI

struct ConfigurationPane {
    let name: String
    let content: AnyView

    init<V: View>(_ name: String, @ViewBuilder content: @escaping () -> V) {
        self.name = name
        self.content = AnyView(content())
    }
}
