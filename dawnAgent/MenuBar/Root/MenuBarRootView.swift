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
    let modalPresentationState: MenuBarModalPresentationState

    @State private var route: MenuBarRoute = .contextList

    var body: some View {
        Group {
            switch route {
            case .contextList:
                MenuBarContextListView(
                    workspace: workspace,
                    openApp: openApp,
                    modalPresentationState: modalPresentationState,
                    onCreateContext: {
                        route = .contextCreation
                    }
                )

            case .contextCreation:
                ContextCreationFlowView(
                    workspace: workspace,
                    modalPresentationState: modalPresentationState,
                    onExit: {
                    route = .contextList
                })
            }
        }
        .frame(
            width: 360,
            height: 600,
            alignment: .top
        )
        .background {
            DawnColors.primaryBackground
                .ignoresSafeArea()
        }
    }
}
