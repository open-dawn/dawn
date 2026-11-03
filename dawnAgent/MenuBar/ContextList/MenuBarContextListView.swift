//
//  MenuBarContextListView.swift
//  dawn
//
//  Created by Rafael Venetikides on 27/10/26.
//

import SwiftUI
import libdawn
import libdawnUI

struct MenuBarContextListView: View {
    let onCreateContext: () -> Void

    private let activityTextFormatter = WorkspaceActivityTextFormatter()

    private let modalPresentationState: MenuBarModalPresentationState

    @State private var viewModel: MenuBarContextListViewModel

    init(
        workspace: WorkspaceRuntime,
        openApp: @escaping (DawnAppRoute) async throws -> Void,
        modalPresentationState: MenuBarModalPresentationState,
        onCreateContext: @escaping () -> Void
    ) {
        self.modalPresentationState = modalPresentationState
        self.onCreateContext = onCreateContext

        _viewModel = State(
            initialValue: MenuBarContextListViewModel(
                workspace: workspace,
                openApp: openApp
            )
        )
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            contextList(relativeTo: timeline.date)
        }
        .onChange(of: viewModel.errorMessage != nil) { _, isPresented in
            modalPresentationState.setPresented(
                isPresented,
                for: .contextListError
            )
        }
        .onChange(of: viewModel.contextPendingDeletion != nil) { _, isPresented in
            modalPresentationState.setPresented(
                isPresented,
                for: .deleteConfirmation
            )
        }
        .onDisappear {
            modalPresentationState.setPresented(
                false,
                for: .contextListError
            )

            modalPresentationState.setPresented(
                false,
                for: .deleteConfirmation
            )
        }
    }
}

// MARK: - Context list layout

extension MenuBarContextListView {
    private func contextList(relativeTo now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            menuHeader
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 4)

            contextsScrollView(relativeTo: now)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
        )
        .alert(
            "Couldn't Complete Action",
            isPresented: isShowingActivationError
        ) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(
            "Delete Context?",
            isPresented: isShowingDeleteConfirmation,
            presenting: viewModel.contextPendingDeletion
        ) { context in
            Button("Cancel", role: .cancel) {
                viewModel.cancelDeletion()
            }

            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.confirmDeletion(of: context)
                }
            }
        } message: { context in
            Text(
                """
                Are you sure you want to delete "\(context.name)"? \
                Its applications and files will not be deleted
                """
            )
        }
    }

    private var menuHeader: some View {
        HStack(spacing: 5) {
            DawnBrand()

            Spacer()

            DButton(
                style: .icon,
                action: {
                    onCreateContext()
                },
                content: {
                    Image(systemName: "plus")
                        .font(DawnTextStyle.actionIcon)
                }
            )
            .accessibilityLabel("Create a context")

            DButton(
                style: .icon,
                action: {
                    Task {
                        await viewModel.open(.settings)
                    }
                },
                content: {
                    Image(systemName: "gearshape")
                        .font(DawnTextStyle.actionIcon)
                }
            )
            .disabled(viewModel.isPerformingOperation)
            .accessibilityLabel("Open DAWN settings")
            .help("Open DAWN settings")
        }
    }

    private func contextsScrollView(relativeTo now: Date) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4, pinnedViews: [.sectionHeaders]) {
                if let activeContext = viewModel.activeContext {
                    contextCard(for: activeContext, relativeTo: now)
                        .padding(.vertical, 12)
                }

                Section {
                    contextsContent(relativeTo: now)
                } header: {
                    contextsSectionHeader
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxHeight: .infinity)
    }

    private var contextsSectionHeader: some View {
        HStack {
            Text("Contexts")
                .font(DawnTextStyle.sectionLabel)

            Spacer()
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(DawnColors.primaryBackground)
    }

    @ViewBuilder
    private func contextsContent(relativeTo now: Date) -> some View {
        if viewModel.inactiveContexts.isEmpty && viewModel.activeContext == nil {
            ContentUnavailableView(
                "No Contexts",
                systemImage: "square.stack",
                description: Text("Create a context to see it here.")
            )
            .frame(maxWidth: .infinity)
        } else if viewModel.inactiveContexts.isEmpty {
            ContentUnavailableView(
                "No other contexts",
                systemImage: "square.stack"
            )
            .frame(maxWidth: .infinity)
        } else {
            ForEach(viewModel.inactiveContexts) { context in
                contextCard(for: context, relativeTo: now)
            }
        }
    }
}

// MARK: - Context cards

extension MenuBarContextListView {

    private func contextCard(for context: WorkspaceContext, relativeTo now: Date) -> some View {
        ContextCard(
            model: contextCardModel(for: context, relativeTo: now),
            isLoading: viewModel.isLoading(context),
            onSelect: {
                Task {
                    await viewModel.select(context)
                }
            },
            onAction: { action in
                Task {
                    await viewModel.handle(action, for: context)
                }
            }
        ).disabled(viewModel.isPerformingOperation)
    }

    private func contextCardModel(for context: WorkspaceContext, relativeTo now: Date) -> ContextCardModel {
        let status: ContextCardModel.Status

        if viewModel.workspace.activeContextID == context.id {
            let activityText =
                viewModel.workspace.activeSince.map {
                    activityTextFormatter.activeText(
                        since: $0,
                        relativeTo: now
                    )
                } ?? "In use"

            status = .active(activityText: activityText)
        } else {
            let lastUsedText = viewModel.workspace.lastActiveAt(for: context.id).map {
                activityTextFormatter.lastUsedText(
                    at: $0,
                    relativeTo: now
                )
            }

            status = .inactive(lastUsedText: lastUsedText)
        }

        return ContextCardModel(
            id: context.id,
            name: context.name,
            symbolName: context.symbol,
            status: status,
            applications: context.applications.map {
                MenuBarContextCardApplicationMapper.makeModel(for: $0)
            }
        )
    }
}

// MARK: - Bindings

extension MenuBarContextListView {
    private var isShowingActivationError: Binding<Bool> {
        Binding(
            get: {
                viewModel.errorMessage != nil
            },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissError()
                }
            }
        )
    }

    private var isShowingDeleteConfirmation: Binding<Bool> {
        Binding(
            get: {
                viewModel.contextPendingDeletion != nil
            },
            set: { isPresented in
                if !isPresented {
                    viewModel.cancelDeletion()
                }
            }
        )
    }
}
