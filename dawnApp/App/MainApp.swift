import SwiftUI

@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor(SettingsAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environment(appDelegate.eventBusService)
                .environment(appDelegate.contextStore)
                .environment(appDelegate.settingsStore)
                .handlesExternalEvents(
                    preferring: ["*"],
                    allowing: ["*"]
                )
                .task(id: appDelegate.eventBusService.isConnected) {
                    guard appDelegate.eventBusService.isConnected else {
                        return
                    }

                    await appDelegate.contextStore.refresh()
                    await appDelegate.settingsStore.refresh()
                }
        }
        .defaultSize(width: 1080, height: 680)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}
