//
//  MenuBarRootView.swift
//  dawn
//
//  Created by Rafael Venetikides on 15/10/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers
import libdawn
import libdawnUI

struct MenuBarRootView: View {
    private enum MenuBarRoute {
        case contextList
        case contextCreation
    }

    let workspace: WorkspaceRuntime
    let openApp: (DawnAppRoute) async throws -> Void

    private let activityTextFormatter = WorkspaceActivityTextFormatter()

    @State private var activatingContextID: UUID?
    @State private var activationError: String?
    @State private var route: MenuBarRoute = .contextList
    @State private var openingRoute: DawnAppRoute?

    var body: some View {
        Group {
            switch route {
            case .contextList:
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    contextList(relativeTo: timeline.date)
                }
            case .contextCreation:
                ContextCreationFlowView {
                    route = .contextList
                }
            }
        }
        .background {
            DawnColors.primaryBackground
                .ignoresSafeArea()
        }
    }
}

// MARK: - Context list layout

extension MenuBarRootView {
    private var activeContext: WorkspaceContext? {
        guard let activeContextID = workspace.activeContextID else {
            return nil
        }

        return workspace.contexts.first {
            $0.id == activeContextID
        }
    }

    private var inactiveContexts: [WorkspaceContext] {
        workspace.contexts.filter {
            $0.id != workspace.activeContextID
        }
    }

    private var isPerformingOperation: Bool {
        activatingContextID != nil || openingRoute != nil
    }

    private func contextList(relativeTo now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            menuHeader
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 4)

            contextsScrollView(relativeTo: now)
        }
        .frame(width: 320)
        .alert(
            "Couldn't Complete Action",
            isPresented: isShowingActivationError
        ) {
            Button("OK") {
                activationError = nil
            }
        } message: {
            Text(activationError ?? "")
        }
    }

    private var menuHeader: some View {
        HStack(spacing: 5) {
            DawnBrand()

            Spacer()

            DButton(
                style: .icon,
                action: {
                    route = .contextCreation
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
                    openInApp(.settings)
                },
                content: {
                    Image(systemName: "gearshape")
                        .font(DawnTextStyle.actionIcon)
                }
            )
            .disabled(isPerformingOperation)
            .accessibilityLabel("Open DAWN settings")
            .help("Open DAWN settings")
        }
    }

    private func contextsScrollView(relativeTo now: Date) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4, pinnedViews: [.sectionHeaders]) {
                if let activeContext {
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
        .frame(maxHeight: 380)
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
        if workspace.contexts.isEmpty {
            ContentUnavailableView(
                "No Contexts",
                systemImage: "square.stack",
                description: Text("Create a context to see it here.")
            )
            .frame(maxWidth: .infinity)
        } else if inactiveContexts.isEmpty {
            ContentUnavailableView(
                "No other contexts",
                systemImage: "square.stack"
            )
            .frame(maxWidth: .infinity)
        } else {
            ForEach(inactiveContexts) { context in
                contextCard(for: context, relativeTo: now)
            }
        }
    }
}

// MARK: - Context cards

extension MenuBarRootView {

    private func contextCard(for context: WorkspaceContext, relativeTo now: Date) -> some View {
        let contextRoute = DawnAppRoute.context(context.id)

        return ContextCard(
            model: contextCardModel(for: context, relativeTo: now),
            isLoading: activatingContextID == context.id || openingRoute == contextRoute,
            onSelect: {
                guard workspace.activeContextID != context.id else {
                    return
                }

                activate(context)
            },
            onAction: { action in
                handle(action, for: context)
            }
        ).disabled(isPerformingOperation)
    }

    private func contextCardModel(for context: WorkspaceContext, relativeTo now: Date) -> ContextCardModel {
        let status: ContextCardModel.Status

        if workspace.activeContextID == context.id {
            let activityText =
                workspace.activeSince.map {
                    activityTextFormatter.activeText(
                        since: $0,
                        relativeTo: now
                    )
                } ?? "In use"

            status = .active(activityText: activityText)
        } else {
            let lastUsedText = workspace.lastActiveAt(for: context.id).map {
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
            applications: context.applications.map(
                contextCardApplication
            )
        )
    }

    private func contextCardApplication(from application: WorkspaceApplication) -> ContextCardModel.Application {
        let applicationURL =
            application.applicationURL
            ?? NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: application
                    .bundleIdentifier
            )

        let icon =
            applicationURL.map {
                NSWorkspace.shared.icon(forFile: $0.path(percentEncoded: false))
            }
            ?? NSWorkspace.shared.icon(for: .application)

        return ContextCardModel.Application(
            id: application.id,
            name: application.displayName,
            icon: icon
        )
    }
}

// MARK: - Actions

extension MenuBarRootView {
    private func handle(_ action: ContextCardAction, for context: WorkspaceContext) {
        switch action {
        case .activate:
            activate(context)

        case .openInApp:
            openInApp(.context(context.id))

        case .stop, .delete:
            // PIN-122: Implement these actions in the functionality issue.
            break
        }
    }

    private func activate(_ context: WorkspaceContext) {
        guard !isPerformingOperation else {
            return
        }

        activatingContextID = context.id
        activationError = nil

        Task {
            defer {
                activatingContextID = nil
            }

            do {
                try await workspace.activateContext(id: context.id)
            } catch {
                activationError = error.localizedDescription
            }
        }
    }

    private var isShowingActivationError: Binding<Bool> {
        Binding(
            get: {
                activationError != nil
            },
            set: { isPresented in
                if !isPresented {
                    activationError = nil
                }
            }
        )
    }

    private func openInApp(_ route: DawnAppRoute) {
        guard !isPerformingOperation else {
            return
        }

        openingRoute = route
        activationError = nil

        Task {
            defer {
                openingRoute = nil
            }

            do {
                try await openApp(route)
            } catch {
                activationError = error.localizedDescription
            }
        }
    }
}
