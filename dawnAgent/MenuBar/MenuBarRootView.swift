//
//  MenuBarRootView.swift
//  dawn
//
//  Created by Rafael Venetikides on 15/10/26.
//

import SwiftUI

struct MenuBarRootView: View {
    let workspace: WorkspaceRuntime

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DAWN")
                .font(.headline)

            Divider()

            Text("\(workspace.contexts.count) contexts")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 320)
    }
}