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
        case workspaceList
        case workspaceCreation
    }

    let workspace: WorkspaceRuntime
    let openApp: (DawnAppRoute) async throws -> Void
    let modalPresentationState: MenuBarModalPresentationState

    @State private var route: MenuBarRoute = .workspaceList

    var body: some View {
        Group {
            switch route {
            case .workspaceList:
                MenuBarWorkspaceListView(
                    workspace: workspace,
                    openApp: openApp,
                    modalPresentationState: modalPresentationState,
                    onCreateWorkspace: {
                        route = .workspaceCreation
                    }
                )

            case .workspaceCreation:
                MenuBarWorkspaceCreationView(
                    workspace: workspace,
                    modalPresentationState: modalPresentationState,
                    onExit: {
                        route = .workspaceList
                    }
                )
            }
        }
        .frame(
            width: 360,
            height: 600,
            alignment: .top
        )
        .background {
            DawnColors.primaryBackground
                .overlay(alignment: .bottom) {
                    DuskMenuBarBackground()
                        .frame(
                            maxWidth: .infinity,
                            alignment: .bottom
                        )
                }
                .ignoresSafeArea()
        }
    }
}
