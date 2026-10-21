//
//  MenuBarRootView.swift
//  dawn
//
//  Created by Rafael Venetikides on 15/10/26.
//

import AppKit
import SwiftUI
import libdawn
import libdawnUI

struct MenuBarRootView: View {
    private enum MenuBarRoute {
        case contextList
        case contextCreation
    }

    let workspace: WorkspaceRuntime

    @State private var activatingContextID: UUID?
    @State private var activationError: String?
    @State private var route: MenuBarRoute = .contextList

    var body: some View {
        switch route {
        case .contextList:
            contextList
        case .contextCreation:
            ContextCreationFlowView {
                route = .contextList
            }
        }
    }

    private var contextList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 5) {
                Image(systemName: "sun.horizon")
                    .font(.system(size: 24))

                Text("dawn")
                    .font(.system(size: 24))

                Spacer()

                Button {
                    route = .contextCreation
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .light))
                }
                .buttonStyle(.plain)

                Button {
                    // PIN-122: Open dawnApp in general settings view
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .light))
                }
                .buttonStyle(.plain)
            }

            // PIN-122: If there is a active context, it should appear here above the list

            HStack(alignment: .center) {
                Text("Contexts")
                    .font(.system(size: 12, weight: .light))

                Spacer()

                Button {
                    // PIN-122: Open dawnApp in current/latest context settings
                } label: {
                    Text("view in app")
                        .font(.system(size: 12, weight: .light))
                        .underline()
                }
                .buttonStyle(.plain)
            }

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
                            contextCard(for: context)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .padding(16)
        .frame(width: 320)
        .alert(
            "Couldn't Switch Context",
            isPresented: isShowingActivationError
        ) {
            Button("OK") {
                activationError = nil
            }
        } message: {
            Text(activationError ?? "")
        }
    }

    private func contextCard(for context: WorkspaceContext) -> some View {
        ContextCard(
            model: contextCardModel(for: context),
            isLoading: activatingContextID == context.id,
            onSelect: {
                guard workspace.lastRequestedContextID != context.id else {
                    return
                }

                activate(context)
            },
            onAction: { action in
                handle(action, for: context)
            }
        ).disabled(activatingContextID != nil && activatingContextID != context.id)
    }

    private func contextCardModel(for context: WorkspaceContext) -> ContextCardModel {
        let status: ContextCardModel.Status

        if workspace.lastRequestedContextID == context.id {
            status = .active(activityText: "In use")
        } else {
            status = .inactive(lastUsedText: nil)
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
                NSWorkspace.shared.icon(forFile: $0.path)
            } ?? NSImage(
                systemSymbolName: "app",
                accessibilityDescription: application.displayName
            ) ?? NSImage(size: NSSize(width: 18, height: 18))

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
        case .stop, .openInApp, .delete:
            // PIN-122: Implement these actions in the functionality issue.
            break
        }
    }

    private func activate(_ context: WorkspaceContext) {
        guard activatingContextID == nil else {
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
}
