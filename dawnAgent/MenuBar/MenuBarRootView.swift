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

    private var isPerformingOperation: Bool {
        activatingContextID != nil || openingRoute != nil
    }

    var body: some View {
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

    private func contextList(relativeTo now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            menuHeader
            contextsHeader
            contextsContent(relativeTo: now)
        }
        .padding(16)
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

    private var contextsHeader: some View {
        // PIN-122: If there is a active context, it should appear here above the list

        HStack(alignment: .center) {
            Text("Contexts")
                .font(DawnTextStyle.sectionLabel)

            Spacer()

            DButton(
                style: .compactLink,
                action: {
                    // PIN-122: Open dawnApp in current/latest context settings
                },
                content: {
                    Text("view in app")
                }
            )
        }
    }

    @ViewBuilder
    private func contextsContent(relativeTo now: Date) -> some View {
        if workspace.contexts.isEmpty {
            ContentUnavailableView(
                "No Contexts",
                systemImage: "square.stack",
                description: Text("Create a context to see it here.")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(workspace.contexts) { context in
                        contextCard(for: context, relativeTo: now)
                    }
                }
            }
            .frame(maxHeight: 280)
        }
    }

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
            let activityText = workspace.activeSince.map {
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
