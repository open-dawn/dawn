//
//  ContextOpeningBehaviourStepView+Previews.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/10/26.
//

#if DEBUG

import SwiftUI

private struct ContextOpeningBehaviorStepPreview: View {
    @State private var selectedBehavior: ContextOpeningBehavior = .hideOthers

    var body: some View {
        ContextOpeningBehaviorStepView(
            selectedBehavior: $selectedBehavior,
            onFinish: {}
        )
        .padding(16)
        .frame(width: 320)
        .background(.regularMaterial)
        .preferredColorScheme(.dark)
    }
}

#Preview("Opening behavior") {
    ContextOpeningBehaviorStepPreview()
}

#endif
