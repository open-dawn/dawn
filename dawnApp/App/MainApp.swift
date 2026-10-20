import SwiftUI

@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor(SettingsAppDelegate.self) private var appDelegate

    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var selectedDestination: SidebarDestination? = SidebarDestination.initial

    var body: some Scene {
        WindowGroup {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                List(SidebarDestination.allCases, selection: $selectedDestination) { destination in
                    Label(destination.title, systemImage: destination.systemImage)
                        .tag(destination)
                }
                .navigationTitle("DAWN")
            } detail: {
                detail(for: selectedDestination)
                    .padding(16)
            }
            .environment(appDelegate.eventBusService)
            .environment(appDelegate.contextStore)
            .task(id: appDelegate.eventBusService.isConnected) {
                guard appDelegate.eventBusService.isConnected else {
                    return
                }

                await appDelegate.contextStore.refresh()
            }
        }
    }

    @ViewBuilder
    private func detail(for destination: SidebarDestination?) -> some View {
        switch destination {
        case .profiles:
            WorkspaceSwitcherView()

        case .settings:
            GeneralSettingsView()

        case .about:
            AboutView(
                content: AboutMetadataLoader.loadRequired()
            )

        case nil:
            ContentUnavailableView(
                "No destination selected",
                systemImage: "sidebar.leading",
                description: Text("Select an item in the sidebar to see its contents.")
            )
        }
    }
}
