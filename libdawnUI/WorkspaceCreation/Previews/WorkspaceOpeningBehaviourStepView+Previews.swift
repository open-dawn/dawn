//
//  WorkspaceOpeningBehaviourStepView+Previews.swift
//  dawn
//

#if DEBUG

import libdawn
import SwiftUI

private struct WorkspaceOpeningBehaviorStepPreview: View {
    @State private var selectedPolicy: WorkspaceActivationPolicy = .hide

    var body: some View {
        WorkspaceOpeningBehaviorStepView(
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
    WorkspaceOpeningBehaviorStepPreview()
}

#endif
