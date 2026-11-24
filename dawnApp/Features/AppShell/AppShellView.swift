import libdawn
import libdawnUI
import SwiftUI

struct AppShellView: View {
    @Environment(SettingsWorkspaceStore.self)
    private var workspaceStore

    @Environment(SettingsEventBusService.self)
    private var eventBusService

    @Environment(SettingsViewStore.self)
    private var settingsStore

    @State private var analyticsConsent = AnalyticsConsentStore()

    var body: some View {
        AppShellContent(
            store: workspaceStore,
        )
        .frame(
            width: SidebarMetrics.windowWidth,
            height: SidebarMetrics.windowHeight
        )
        .onChange(of: eventBusService.isConnected, initial: true) { _, isConnected in
            analyticsConsent.presentIfNeeded(
                isAgentConnected: isConnected,
                hasLoadedSettings: settingsStore.hasLoaded
            )
        }
        .onChange(of: settingsStore.hasLoaded, initial: true) { _, hasLoaded in
            analyticsConsent.presentIfNeeded(
                isAgentConnected: eventBusService.isConnected,
                hasLoadedSettings: hasLoaded
            )
        }
        .sheet(
            isPresented: Binding(
                get: { analyticsConsent.isPresented },
                set: { _ in }
            )
        ) {
            AnalyticsConsentView(
                isSubmitting: analyticsConsent.isSubmitting,
                errorMessage: analyticsConsent.errorMessage,
                onChoose: { enabled in
                    Task {
                        await analyticsConsent.submit(
                            analyticsEnabled: enabled,
                            settingsStore: settingsStore
                        )
                    }
                }
            )
        }
    }

    fileprivate struct AppShellContent: View {
        let store: SettingsWorkspaceStore

        @Environment(SettingsEventBusService.self)
        private var eventBusService

        @Environment(AccessibilityPermissionService.self)
        private var accessibilityPermissionService

        @Environment(AppUpdaterService.self)
        private var updaterService

        @Environment(SettingsViewStore.self)
        private var settingsStore

        @State private var viewModel: WorkspaceDetailViewModel
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

        private var activeWorkspaces: [Workspace] {
            store.workspaces.filter { !$0.isArchived }
        }

        private var archivedWorkspaces: [Workspace] {
            store.workspaces.filter(\.isArchived)
        }

        init(store: SettingsWorkspaceStore) {
            self.store = store

            _viewModel = State(
                initialValue: WorkspaceDetailViewModel(workspaceCatalog: store)
            )
            _navigation = State(initialValue: AppNavigationModel())
        }

        var body: some View {
            HStack(spacing: 0) {
                SidebarView(
                    content: SidebarContent(
                        workspaces: activeWorkspaces,
                        archivedWorkspaces: archivedWorkspaces,
                        activity: store.activity,
                        busyWorkspaceID: viewModel.operationInProgress,
                        isLoading: store.isLoading,
                        isAgentRunning: eventBusService.isConnected,
                        needsAccessibilityPermission: accessibilityPermissionService.isTrusted == false,
                        interactionsDisabled: interactionsDisabled,
                        errorMessages: sidebarErrors
                    ),
                    availableUpdate: availableUpdate,
                    selectedDestination: $navigation.selectedDestination,
                    onCreateWorkspace: { viewModel.presentWorkspaceCreator() },
                    onDismissError: dismissSidebarError
                )
                .frame(maxHeight: .infinity)

                detail(for: navigation.selectedDestination)
                    .frame(width: SidebarMetrics.detailWidth)
                    .frame(maxHeight: .infinity)
                    .background {
                        DawnColors.primaryBackground
                    }
            }
            .frame(
                minWidth: SidebarMetrics.windowWidth,
                idealWidth: SidebarMetrics.windowWidth,
                maxWidth: SidebarMetrics.windowWidth,
                minHeight: SidebarMetrics.windowHeight,
                idealHeight: SidebarMetrics.windowHeight,
                maxHeight: SidebarMetrics.windowHeight
            )
            .background {
                shellBackground
            }
            .background {
                WindowTranslucency()
            }
            .onChange(of: store.workspaces) { _, workspaces in
                navigation.workspacesDidChange(workspaces)
                viewModel.reconcileActiveWorkspace(with: workspaces.filter { !$0.isArchived })
            }
            .onChange(of: store.activity.activeWorkspaceID, initial: true) { _, activeWorkspaceID in
                viewModel.synchronizeActiveWorkspace(activeWorkspaceID)
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

                await refreshWorkspacesAndResolvePendingRoute()
                navigation.selectInitialWorkspaceIfNeeded(from: store.workspaces)
            }
            .sheet(
                isPresented: Binding<Bool>(
                    get: { viewModel.isCreatingOrEditing },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.dismissWorkspaceCreator()
                        }
                    }
                ),
                onDismiss: {
                    viewModel.dismissWorkspaceCreator()

                    Task {
                        await store.refresh()
                    }
                },
                content: {
                    WorkspaceCreatorView()
                }
            )
            .alert("Couldn't Open Workspace", isPresented: isShowingNavigationError) {
                Button("OK") {
                    navigation.dismissError()
                }
            } message: {
                Text(navigation.error?.localizedDescription ?? "")
            }
        }

        private var shellBackground: some View {
            HStack(spacing: 0) {
                SidebarBackground()
                    .frame(width: SidebarMetrics.width)

                DawnColors.primaryBackground
            }
            .ignoresSafeArea()
        }

        private func pushSidebarError(_ message: String?) {
            guard let message, !message.isEmpty else {
                return
            }

            if message == SettingsViewStoreError.notConnected.errorDescription
                || message == SettingsWorkspaceStoreError.notConnected.errorDescription
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
            _ previous: SettingsWorkspaceStoreError?,
            _ error: SettingsWorkspaceStoreError?,
            allowsDisconnected: Bool = true
        ) {
            if previous?.isEmptyWorkspaceName == true {
                sidebarErrors.removeAll { $0.text == previous?.localizedDescription }
            }

            // An empty name is shown beside the name field, not in the sidebar.
            guard error?.isEmptyWorkspaceName != true else { return }
            guard allowsDisconnected || error != .notConnected else { return }

            pushSidebarError(error?.localizedDescription)
        }

        private func dismissSidebarError() {
            if !sidebarErrors.isEmpty {
                sidebarErrors.removeFirst()
            }

            if viewModel.error?.isEmptyWorkspaceName != true {
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
        case let .workspace(workspaceID):
            if !eventBusService.isConnected {
                AgentWaitingView()
            } else if let workspace = store.workspaces.first(where: { $0.id == workspaceID }) {
                WorkspaceDetailView(
                    workspace: workspace,
                    viewModel: viewModel,
                    interactionsDisabled: interactionsDisabled,
                    onDelete: { deleted in
                        if navigation.selectedDestination == .workspace(deleted.id) {
                            navigation.selectedDestination = nil
                            navigation.selectInitialWorkspaceIfNeeded(from: store.workspaces)
                        }
                    }
                )
            } else {
                EmptyWorkspacesView(
                    onCreateWorkspace: { viewModel.presentWorkspaceCreator() },
                    interactionsDisabled: interactionsDisabled
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
            if !eventBusService.isConnected {
                AgentWaitingView()
            } else {
                EmptyWorkspacesView(
                    onCreateWorkspace: { viewModel.presentWorkspaceCreator() },
                    interactionsDisabled: interactionsDisabled
                )
            }
        }
    }

    fileprivate func handleOpenURL(_ url: URL) {
        guard let route = DawnAppRoute(url: url) else { return }

        let requiresRefresh = navigation.receive(
            route,
            availableWorkspaces: store.workspaces
        )

        guard requiresRefresh, eventBusService.isConnected else {
            return
        }

        Task {
            await refreshWorkspacesAndResolvePendingRoute()
        }
    }

    fileprivate func refreshWorkspacesAndResolvePendingRoute() async {
        await store.refresh()
        guard navigation.pendingRoute != nil else { return }

        if store.error == nil {
            navigation.workspaceRefreshSucceeded(with: store.workspaces)
        } else {
            navigation.workspaceRefreshFailed()
        }
    }
}
