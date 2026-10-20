import libdawn
import SwiftUI

struct AppShellView: View {
    @Environment(SettingsContextStore.self)
    private var contextStore

    var body: some View {
        AppShellContent(store: contextStore)
    }
}

private struct AppShellContent: View {
    let store: SettingsContextStore

    @Environment(SettingsEventBusService.self)
    private var eventBusService

    @State private var viewModel: ContextDetailViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var selectedDestination: SidebarDestination?
    @State private var searchText = ""
    @State private var isArchivedSectionExpanded = false

    private var filteredContexts: [WorkspaceContext] {
        ContextSearchFilter.filter(store.contexts, searchText: searchText)
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The archived section starts collapsed, but always expands while
    /// searching so matching (or missing) archived results are visible.
    private var archivedSectionExpansion: Binding<Bool> {
        Binding(
            get: { isArchivedSectionExpanded || isSearching },
            set: { isArchivedSectionExpanded = $0 }
        )
    }

    private var interactionsDisabled: Bool {
        !eventBusService.isConnected || store.isLoading || viewModel.operationInProgress != nil
    }

    init(store: SettingsContextStore) {
        self.store = store
        _viewModel = State(
            initialValue: ContextDetailViewModel(
                contextManager: store
            )
        )
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detail(for: selectedDestination)
                .padding(16)
        }
        .onChange(of: store.contexts) { _, contexts in
            selectedDestination = selectedDestination?.reconciled(with: contexts)
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
                ContextCreatorView(context: viewModel.contextBeingEdited)
            }
        )
    }

    private var sidebar: some View {
        List(selection: $selectedDestination) {
            Section {
                Button {
                    viewModel.presentContextCreator()
                } label: {
                    Label("New Context", systemImage: "plus")
                }
                .disabled(interactionsDisabled)
                .selectionDisabled()
            }

            Section(
                content: {
                    contextsSectionContent
                },
                header: {
                    HStack {
                        Text("Contexts")

                        Spacer()

                        Button {
                            viewModel.presentContextCreator()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                        .disabled(interactionsDisabled)
                        .help("Create a new context")
                        .accessibilityLabel("Create a new context")
                    }
                }
            )

            Section(
                isExpanded: archivedSectionExpansion,
                content: {
                    Text(isSearching ? "No archived contexts found" : "No archived contexts")
                        .foregroundStyle(.secondary)
                        .selectionDisabled()
                },
                header: {
                    Text("Archived contexts")
                }
            )

            if let error = viewModel.error ?? store.error {
                Section {
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .selectionDisabled()

                    Button("Dismiss") {
                        viewModel.dismissError()
                        store.dismissError()
                    }
                    .selectionDisabled()
                }
            }

            Section {
                Label("Settings", systemImage: "gearshape")
                    .tag(SidebarDestination.settings)

                Label("About", systemImage: "info.circle")
                    .tag(SidebarDestination.about)
            }
        }
        .navigationTitle("DAWN")
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search contexts")
    }

    @ViewBuilder
    private var contextsSectionContent: some View {
        if !eventBusService.isConnected {
            Label(
                "Workspace manager is not connected. Context actions are unavailable.",
                systemImage: "bolt.slash"
            )
            .foregroundStyle(.orange)
            .selectionDisabled()
        }

        if store.isLoading && store.contexts.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)

                Text("Loading contexts...")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .selectionDisabled()
        } else if store.contexts.isEmpty {
            Text("No contexts")
                .foregroundStyle(.secondary)
                .selectionDisabled()
        } else if filteredContexts.isEmpty {
            Text("No contexts matching \"\(searchText)\"")
                .foregroundStyle(.secondary)
                .selectionDisabled()
        } else {
            ForEach(filteredContexts) { context in
                Label(context.name, systemImage: context.symbol)
                    .tag(SidebarDestination.context(context.id))
            }
        }
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
            GeneralSettingsView()

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
