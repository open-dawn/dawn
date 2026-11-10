import libdawn
import libdawnUI
import SwiftUI

struct AppShellView: View {
    @Environment(SettingsContextStore.self)
    private var contextStore

    var body: some View {
        AppShellContent(
            store: contextStore,
        )
        .frame(
            minWidth: SidebarMetrics.width + SidebarMetrics.minimumDetailWidth,
            maxWidth: .infinity,
            minHeight: SidebarMetrics.minimumWindowHeight,
            maxHeight: .infinity
        )
    }

    fileprivate struct AppShellContent: View {
        let store: SettingsContextStore

        @Environment(SettingsEventBusService.self)
        private var eventBusService

        @Environment(AccessibilityPermissionService.self)
        private var accessibilityPermissionService

        @Environment(AppUpdaterService.self)
        private var updaterService

        @Environment(SettingsViewStore.self)
        private var settingsStore

        @State private var viewModel: ContextDetailViewModel
        @State private var navigation: AppNavigationModel
        @State private var sidebarErrors: [SidebarErrorMessage] = []

        private static let maxSidebarErrors = 8

        private var interactionsDisabled: Bool {
            !eventBusService.isConnected || store.isLoading || viewModel.operationInProgress != nil
        }

        private var isShowingNavigationError: Binding<Bool> {
            Binding(
                get: { navigation.error != nil },
                set: { isPresented in
                    if !isPresented {
                        navigation.dismissError()
                    }
                }
            )
        }

        private var availableUpdate: AvailableAppUpdate? {
            guard case let .updateAvailable(update) = updaterService.state else {
                return nil
            }

            return update
        }

        private var activeContexts: [WorkspaceContext] {
            store.contexts.filter { !$0.isArchived }
        }

        private var archivedContexts: [WorkspaceContext] {
            store.contexts.filter(\.isArchived)
        }

        init(store: SettingsContextStore) {
            self.store = store

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
                        needsAccessibilityPermission: accessibilityPermissionService.isTrusted == false,
                        interactionsDisabled: interactionsDisabled,
                        errorMessages: sidebarErrors
                    ),
                    availableUpdate: availableUpdate,
                    selectedDestination: $navigation.selectedDestination,
                    onCreateContext: { viewModel.presentContextCreator() },
                    onDismissError: dismissSidebarError
                )
                .background {
                    SplitViewDividerFix()
                }

                detail(for: navigation.selectedDestination)
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
            .onChange(of: store.contexts) { _, contexts in
                navigation.contextsDidChange(contexts)
                viewModel.reconcileActiveContext(with: contexts.filter { !$0.isArchived })
            }
            .onChange(of: viewModel.error) { previous, error in
                presentSidebarError(previous, error)
            }
            .onChange(of: store.error) { previous, error in
                presentSidebarError(previous, error, allowsDisconnected: false)
            }
            .onChange(of: settingsStore.error) { _, error in
                guard error != .notConnected else {
                    return
                }

                pushSidebarError(error?.localizedDescription)
            }
            .onChange(of: accessibilityPermissionService.error?.errorDescription) { _, message in
                pushSidebarError(message)
            }
            .onOpenURL(perform: handleOpenURL)
            .task(id: eventBusService.isConnected) {
                guard eventBusService.isConnected else {
                    return
                }

                await refreshContextsAndResolvePendingRoute()
            }
            .sheet(
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
                    ContextCreatorView()
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

        private func pushSidebarError(_ message: String?) {
            guard let message, !message.isEmpty else {
                return
            }

            if message == SettingsViewStoreError.notConnected.errorDescription
                || message == SettingsContextStoreError.notConnected.errorDescription
            {
                return
            }

            guard sidebarErrors.first?.text != message else {
                return
            }

            sidebarErrors.insert(SidebarErrorMessage(text: message), at: 0)

            if sidebarErrors.count > Self.maxSidebarErrors {
                sidebarErrors = Array(sidebarErrors.prefix(Self.maxSidebarErrors))
            }
        }

        private func presentSidebarError(
            _ previous: SettingsContextStoreError?,
            _ error: SettingsContextStoreError?,
            allowsDisconnected: Bool = true
        ) {
            if previous?.isEmptyContextName == true {
                sidebarErrors.removeAll { $0.text == previous?.localizedDescription }
            }

            // An empty name is shown beside the name field, not in the sidebar.
            guard error?.isEmptyContextName != true else { return }
            guard allowsDisconnected || error != .notConnected else { return }

            pushSidebarError(error?.localizedDescription)
        }

        private func dismissSidebarError() {
            if !sidebarErrors.isEmpty {
                sidebarErrors.removeFirst()
            }

            if viewModel.error?.isEmptyContextName != true {
                viewModel.dismissError()
            }
            store.dismissError()
            settingsStore.dismissError()
            accessibilityPermissionService.dismissError()
        }
    }
}

extension AppShellView.AppShellContent {
    @ViewBuilder
    fileprivate func detail(for destination: SidebarDestination?) -> some View {
        switch destination {
        case let .context(contextID):
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
                content: AboutContent.loadRequired(),
                updater: updaterService
            )

        case nil:
            ContentUnavailableView(
                "No context selected",
                systemImage: "sidebar.leading",
                description: Text("Select a context in the sidebar, or create a new one.")
            )
        }
    }

    fileprivate func handleOpenURL(_ url: URL) {
        guard let route = DawnAppRoute(url: url) else { return }

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

    fileprivate func refreshContextsAndResolvePendingRoute() async {
        await store.refresh()
        guard navigation.pendingRoute != nil else { return }

        if store.error == nil {
            navigation.contextRefreshSucceeded(with: store.contexts)
        } else {
            navigation.contextRefreshFailed()
        }
    }
}
