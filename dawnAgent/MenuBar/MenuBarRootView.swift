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

    @State private var route: MenuBarRoute = .contextList

    var body: some View {
        Group {
            switch route {
            case .contextList:
                MenuBarContextListView(
                    workspace: workspace,
                    openApp: openApp,
                    onCreateContext: {
                        route = .contextCreation
                    }
                )

            case .contextCreation:
                ContextCreationFlowView(
                    workspace: workspace,
                    onExit: {
                    route = .contextList
                })
            }
        }
        .background {
            DawnColors.primaryBackground
                .ignoresSafeArea()
        }
    }
}
