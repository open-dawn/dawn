import SwiftUI

@main
struct PineappleWMApp: App {
    private let screens: [ConfigurationPane] = [
        ConfigurationPane("Profiles") { WorkspaceSwitcherView() },
        ConfigurationPane("General Settings") { Text("Settings") },
        ConfigurationPane("About") { AboutView() }
    ]

    var body: some Scene {
        WindowGroup {
            TabView {
                ForEach(screens, id: \.name) { screen in
                    Tab(screen.name, systemImage: "") {
                        screen.content
                            .padding(16)
                    }
                }
            }
            .padding(0)
        }
        .windowResizability(.contentSize)
    }
}

