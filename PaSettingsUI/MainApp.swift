import SwiftUI

@main
struct MainApp: App {
    private let screens: [ConfigurationPane] = [
        ConfigurationPane("Profiles") { WorkspaceSwitcherView() },
        ConfigurationPane("General Settings") { GeneralSettingsView() },
        ConfigurationPane("About") {
            AboutView(
                content: AboutMetadataLoader.loadRequired()
            )
        }
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
