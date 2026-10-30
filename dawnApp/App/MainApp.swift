import SwiftUI

@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor(SettingsAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environment(appDelegate.eventBusService)
                .environment(appDelegate.contextStore)
                .environment(appDelegate.updaterService)
                .environment(appDelegate.accessibilityPermissionService)
                .environment(appDelegate.settingsStore)
                .handlesExternalEvents(
                    preferring: ["*"],
                    allowing: ["*"]
                )
                .task(id: appDelegate.eventBusService.isConnected) {
                    guard appDelegate.eventBusService.isConnected else {
                        appDelegate.accessibilityPermissionService.clearStatus()
                        return
                    }

                    await appDelegate.contextStore.refresh()
                    await appDelegate.accessibilityPermissionService.refresh()
                    await appDelegate.settingsStore.refresh()
                }
        }
        .defaultSize(width: 1080, height: 680)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}
