//
//  MenuBarWorkspaceListView.swift
//  dawn
//
//  Created by Rafael Venetikides on 27/10/26.
//

import SwiftUI
import libdawn
import libdawnUI

struct MenuBarWorkspaceListView: View {
    let onCreateWorkspace: () -> Void

    private let activityTextFormatter = WorkspaceActivityTextFormatter()

    private let modalPresentationState: MenuBarModalPresentationState

    @State private var viewModel: MenuBarWorkspaceListViewModel

    init(
        workspace: WorkspaceRuntime,
        openApp: @escaping (DawnAppRoute) async throws -> Void,
        modalPresentationState: MenuBarModalPresentationState,
        onCreateWorkspace: @escaping () -> Void
    ) {
        self.modalPresentationState = modalPresentationState
        self.onCreateWorkspace = onCreateWorkspace

        _viewModel = State(
            initialValue: MenuBarWorkspaceListViewModel(
                workspace: workspace,
                openApp: openApp
            )
        )
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            workspaceList(relativeTo: timeline.date)
        }
        .onChange(of: viewModel.errorMessage != nil) { _, isPresented in
            modalPresentationState.setPresented(
                isPresented,
                for: .workspaceListError
            )
        }
        .onChange(of: viewModel.workspacePendingDeletion != nil) { _, isPresented in
            modalPresentationState.setPresented(
                isPresented,
                for: .deleteConfirmation
            )
        }
        .onDisappear {
            modalPresentationState.setPresented(
                false,
                for: .workspaceListError
            )

            modalPresentationState.setPresented(
                false,
                for: .deleteConfirmation
            )
        }
    }
}

// MARK: - Workspace list layout

extension MenuBarWorkspaceListView {
    private func workspaceList(relativeTo now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            menuHeader
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 4)

            if viewModel.inactiveWorkspaces.isEmpty && viewModel.activeWorkspace == nil {
                noWorkspacesView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                workspacesScrollView(relativeTo: now)
            }
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
            "Delete workspace?",
            isPresented: isShowingDeleteConfirmation,
            presenting: viewModel.workspacePendingDeletion
        ) { workspace in
            Button("Cancel", role: .cancel) {
                viewModel.cancelDeletion()
            }

            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.confirmDeletion(of: workspace)
                }
            }
        } message: { workspace in
            Text(
                """
                Are you sure you want to delete "\(workspace.name)"? \
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
                    onCreateWorkspace()
                },
                content: {
                    Image(systemName: "plus.square.fill.on.square.fill")
                        .font(DawnTextStyle.actionIcon)
                }
            )
            .accessibilityLabel("Create a workspace")

            DButton(
                style: .icon,
                action: {
                    Task {
                        await viewModel.open(.settings)
                    }
                },
                content: {
                    Image(systemName: "gearshape.fill")
                        .font(DawnTextStyle.actionIcon)
                }
            )
            .disabled(viewModel.isPerformingOperation)
            .accessibilityLabel("Open DAWN settings")
            .help("Open DAWN settings")
        }
    }

    private func workspacesScrollView(relativeTo now: Date) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4, pinnedViews: [.sectionHeaders]) {
                if let activeWorkspace = viewModel.activeWorkspace {
                    workspaceCard(for: activeWorkspace, relativeTo: now)
                        .padding(.vertical, 12)
                }

                Section {
                    workspacesContent(relativeTo: now)
                } header: {
                    workspacesSectionHeader
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxHeight: .infinity)
    }

    private var workspacesSectionHeader: some View {
        HStack {
            Spacer()

            if !viewModel.runtime.workspaces.isEmpty {
                Text("Your workspaces")
                    .font(DawnTextStyle.sectionLabel)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(DawnColors.primaryBackground)
    }

    @ViewBuilder
    private func workspacesContent(relativeTo now: Date) -> some View {
        if viewModel.inactiveWorkspaces.isEmpty {
            EmptyView()
        } else {
            ForEach(viewModel.inactiveWorkspaces) { workspace in
                workspaceCard(for: workspace, relativeTo: now)
            }
        }
    }

    private var noWorkspacesView: some View {
        VStack {
            DuskSleepy.image(height: 74)

            Text("No Workspaces".uppercased())
                .font(DawnTextStyle.noWorkspaceTitle)

            Text("Create a workspace to see it here")
                .font(DawnTextStyle.noWorkspaceBody)
        }
    }
}

// MARK: - Workspace cards

extension MenuBarWorkspaceListView {

    private func workspaceCard(for workspace: Workspace, relativeTo now: Date) -> some View {
        WorkspaceCard(
            model: workspaceCardModel(for: workspace, relativeTo: now),
            isLoading: viewModel.isLoading(workspace),
            onSelect: {
                Task {
                    await viewModel.select(workspace)
                }
            },
            onAction: { action in
                Task {
                    await viewModel.handle(action, for: workspace)
                }
            }
        ).disabled(viewModel.isPerformingOperation)
    }

    private func workspaceCardModel(for workspace: Workspace, relativeTo now: Date) -> WorkspaceCardModel {
        let status: WorkspaceCardModel.Status

        if viewModel.runtime.activeWorkspaceID == workspace.id {
            let activityText =
                viewModel.runtime.activeSince.map {
                    activityTextFormatter.activeText(
                        since: $0,
                        relativeTo: now
                    )
                } ?? "In use"

            status = .active(activityText: activityText)
        } else {
            let lastUsedText = viewModel.runtime.lastActiveAt(for: workspace.id).map {
                activityTextFormatter.lastUsedText(
                    at: $0,
                    relativeTo: now
                )
            }

            status = .inactive(lastUsedText: lastUsedText)
        }

        return WorkspaceCardModel(
            id: workspace.id,
            name: workspace.name,
            symbolName: workspace.symbol,
            status: status,
            applications: workspace.applications.map {
                MenuBarWorkspaceCardApplicationMapper.makeModel(for: $0)
            }
        )
    }
}

// MARK: - Bindings

extension MenuBarWorkspaceListView {
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
                viewModel.workspacePendingDeletion != nil
            },
            set: { isPresented in
                if !isPresented {
                    viewModel.cancelDeletion()
                }
            }
        )
    }
}
