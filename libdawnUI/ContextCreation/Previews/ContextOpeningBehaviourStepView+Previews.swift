//
//  ContextOpeningBehaviourStepView+Previews.swift
//  dawn
//

#if DEBUG

import libdawn
import SwiftUI

private struct ContextOpeningBehaviorStepPreview: View {
    @State private var selectedPolicy: WorkspaceActivationPolicy = .hide

    var body: some View {
        ContextOpeningBehaviorStepView(
            selectedPolicy: $selectedPolicy,
            onFinish: {}
        )
        .frame(width: 320, height: 600)
        .padding(16)
        .background {
            DawnColors.primaryBackground
        }
    }
}

#Preview("Opening Behaviour Step") {
    ContextOpeningBehaviorStepPreview()
}

#endif
