import SwiftUI
import libdawn
import libdawnUI

struct AppShellView: View {
    @Environment(SettingsContextStore.self)
    private var contextStore
    var availableUpdate: AppUpdateAvailability?

    init(availableUpdate: AppUpdateAvailability? = nil) {
        self.availableUpdate = availableUpdate
    }

    var body: some View {
        AppShellContent(
            store: contextStore,
            availableUpdate: availableUpdate
        )
        .frame(
            minWidth: SidebarMetrics.width + SidebarMetrics.minimumDetailWidth,
            maxWidth: .infinity,
            minHeight: SidebarMetrics.minimumWindowHeight,
            maxHeight: .infinity
        )
    }

    private struct AppShellContent: View {
        let store: SettingsContextStore
        let availableUpdate: AppUpdateAvailability?

        @Environment(SettingsEventBusService.self)
        private var eventBusService

        @State private var viewModel: ContextDetailViewModel
        @State private var navigation: AppNavigationModel

        private var interactionsDisabled: Bool {
            !eventBusService.isConnected || store.isLoading || viewModel.operationInProgress != nil
        }

        private var isShowingNavigationError: Binding<Bool> {
            Binding(
                get: {
                    navigation.error != nil
                },
                set: { isPresented in
                    if !isPresented {
                        navigation.dismissError()
                    }
                }
            )
        }

        private var activeContexts: [WorkspaceContext] {
            store.contexts.filter { !$0.isArchived }
        }

        private var archivedContexts: [WorkspaceContext] {
            store.contexts.filter(\.isArchived)
        }

        init(store: SettingsContextStore, availableUpdate: AppUpdateAvailability?) {
            self.store = store
            self.availableUpdate = availableUpdate
            _viewModel = State(
                initialValue: ContextDetailViewModel(contextManager: store)
            )

            _navigation = State(initialValue: AppNavigationModel())
        }

        var body: some View {
            HSplitView {
                SidebarView(
                    content: SidebarContent(
                        contexts: activeContexts,
                        archivedContexts: archivedContexts,
                        activeContextID: viewModel.activeContextID,
                        busyContextID: viewModel.operationInProgress,
                        isLoading: store.isLoading,
                        isAgentRunning: eventBusService.isConnected,
                        interactionsDisabled: interactionsDisabled,
                        update: availableUpdate,
                        errorMessage: (viewModel.error ?? store.error)?.localizedDescription
                    ),
                    selectedDestination: $navigation.selectedDestination,
                    onCreateContext: { viewModel.presentContextCreator() },
                    onDismissError: dismissSidebarError
                )
                .background {
                    SplitViewDividerFix()
                }

                detail(for: navigation.selectedDestination)
                    .padding(24)
                    .frame(
                        minWidth: SidebarMetrics.minimumDetailWidth,
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                    .background {
                        DawnColors.primaryBackground
                            .ignoresSafeArea()
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .background {
                WindowTranslucency()
            }
            .preferredColorScheme(.dark)
            .onChange(of: store.contexts) { _, contexts in
                navigation.contextsDidChange(contexts)
                viewModel.reconcileActiveContext(with: contexts.filter { !$0.isArchived })
            }
            .onOpenURL(perform: handleOpenURL)
            .task(id: eventBusService.isConnected) {
                guard eventBusService.isConnected else {
                    return
                }

                await refreshContextsAndResolvePendingRoute()
            }
            .sheet(  // PIN-139 Change in future with new creation sheet
                isPresented: Binding<Bool>(
                    get: { viewModel.isCreatingOrEditing },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.dismissContextCreator()
                        }
                    }
                ),
                onDismiss: {
                    viewModel.dismissContextCreator()

                    Task {
                        await store.refresh()
                    }
                },
                content: {
                    ContextCreatorView(context: viewModel.contextBeingEdited)
                }
            )
            .alert("Couldn't Open Context", isPresented: isShowingNavigationError) {
                Button("OK") {
                    navigation.dismissError()
                }
            } message: {
                Text(navigation.error?.localizedDescription ?? "")
            }
        }

        private func dismissSidebarError() {
            viewModel.dismissError()
            store.dismissError()
        }

        @ViewBuilder
        private func detail(for destination: SidebarDestination?) -> some View {
            switch destination {
            case .context(let contextID):
                if let context = store.contexts.first(where: { $0.id == contextID }) {
                    ContextDetailView(
                        context: context,
                        viewModel: viewModel,
                        interactionsDisabled: interactionsDisabled,
                        onDelete: { deleted in
                            if navigation.selectedDestination == .context(deleted.id) {
                                navigation.selectedDestination = nil
                            }
                        }
                    )
                } else {
                    ContentUnavailableView(
                        "Context not available",
                        systemImage: "rectangle.stack.slash",
                        description: Text("This context is no longer available.")
                    )
                }

            #if DEBUG
            case .debug:
                WorkspaceTransitionDebugView()
            #endif

            case .settings:
                SettingsView()

            case .about:
                AboutView(
                    content: AboutContent.loadRequired()
                )

            case nil:
                ContentUnavailableView(
                    "No context selected",
                    systemImage: "sidebar.leading",
                    description: Text("Select a context in the sidebar, or create a new one.")
                )
            }
        }

        private func handleOpenURL(_ url: URL) {
            guard let route = DawnAppRoute(url: url) else {
                return
            }

            let requiresRefresh = navigation.receive(
                route,
                availableContexts: store.contexts
            )

            guard requiresRefresh, eventBusService.isConnected else {
                return
            }

            Task {
                await refreshContextsAndResolvePendingRoute()
            }
        }

        private func refreshContextsAndResolvePendingRoute() async {
            await store.refresh()

            guard navigation.pendingRoute != nil else {
                return
            }

            if store.error == nil {
                navigation.contextRefreshSucceeded(
                    with: store.contexts
                )
            } else {
                navigation.contextRefreshFailed()
            }
        }
    }
}
