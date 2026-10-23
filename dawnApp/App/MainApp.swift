import SwiftUI

@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor(SettingsAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environment(appDelegate.eventBusService)
                .environment(appDelegate.contextStore)
                .handlesExternalEvents(
                    preferring: ["*"],
                    allowing: ["*"]
                )
        }
        .defaultSize(width: 1080, height: 680)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}
