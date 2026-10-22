import SwiftUI

@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor(SettingsAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environment(appDelegate.eventBusService)
                .environment(appDelegate.contextStore)
                .task(id: appDelegate.eventBusService.isConnected) {
                    guard appDelegate.eventBusService.isConnected else {
                        return
                    }

                    await appDelegate.contextStore.refresh()
                }
        }
        .defaultSize(width: 1080, height: 680)
        .windowStyle(.hiddenTitleBar)
        // Never let the window shrink below the shell's minimum
        // (sidebar + minimum detail), which would clip the content
        // instead of resizing it.
        .windowResizability(.contentMinSize)
    }
}
