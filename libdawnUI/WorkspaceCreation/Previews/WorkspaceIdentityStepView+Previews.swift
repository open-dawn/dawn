//
//  WorkspaceIdentityStepView+Previews.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/10/26.
//

#if DEBUG

import SwiftUI

private struct WorkspaceIdentityStepPreview: View {
    @State private var name = "Gaming"
    @State private var selectedSymbolName: String? = "briefcase.fill"

    var body: some View {
        WorkspaceIdentityStepView(
            name: $name,
            selectedSymbolName: $selectedSymbolName,
            onNext: {}
        )
        .padding(16)
        .frame(width: 320)
        .background(.regularMaterial)
        .preferredColorScheme(.dark)
    }
}

#Preview("Identity") {
    WorkspaceIdentityStepPreview()
}

#endif
