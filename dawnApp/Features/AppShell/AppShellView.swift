import libdawn
import libdawnUI
import SwiftUI

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
        @State private var selectedDestination: SidebarDestination?

        private var interactionsDisabled: Bool {
            !eventBusService.isConnected ||
                store.isLoading ||
                viewModel.operationInProgress != nil
        }

        init(store: SettingsContextStore, availableUpdate: AppUpdateAvailability?) {
            self.store = store
            self.availableUpdate = availableUpdate
            _viewModel = State(
                initialValue: ContextDetailViewModel(contextManager: store)
            )
        }

        var body: some View {
            HSplitView {
                SidebarView(
                    content: SidebarContent(
                        contexts: store.contexts,
                        activeContextID: viewModel.activeContextID,
                        busyContextID: viewModel.operationInProgress,
                        isLoading: store.isLoading,
                        isAgentRunning: eventBusService.isConnected,
                        interactionsDisabled: interactionsDisabled,
                        update: availableUpdate,
                        errorMessage: (viewModel.error ?? store.error)?.localizedDescription
                    ),
                    selectedDestination: $selectedDestination,
                    onCreateContext: { viewModel.presentContextCreator() },
                    onDismissError: dismissSidebarError
                )

                detail(for: selectedDestination)
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
                selectedDestination = selectedDestination?.reconciled(with: contexts)
                viewModel.reconcileActiveContext(with: contexts)
            }
            .sheet( // PIN-139 Change in future with new creation sheet
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
        }

        private func dismissSidebarError() {
            viewModel.dismissError()
            store.dismissError()
        }

        @ViewBuilder
        private func detail(for destination: SidebarDestination?) -> some View {
            switch destination {
            case let .context(contextID):
                if let context = store.contexts.first(where: { $0.id == contextID }) {
                    ContextDetailView(
                        context: context,
                        viewModel: viewModel,
                        interactionsDisabled: interactionsDisabled,
                        onDelete: { deleted in
                            if selectedDestination == .context(deleted.id) {
                                selectedDestination = nil
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

            case .settings:
                SettingsView()

            case .about:
                AboutView(
                    content: AboutMetadataLoader.loadRequired()
                )

            case nil:
                ContentUnavailableView(
                    "No context selected",
                    systemImage: "sidebar.leading",
                    description: Text("Select a context in the sidebar, or create a new one.")
                )
            }
        }
    }
}
