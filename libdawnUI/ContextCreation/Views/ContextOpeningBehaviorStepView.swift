//
//  ContextOpeningBehaviorStepView.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/10/26.
//

import SwiftUI
import libdawn

struct ContextOpeningBehaviorStepView: View {
    @Binding var selectedPolicy: WorkspaceActivationPolicy

    let onFinish: () -> Void

    var body: some View {
        VStack {
            Text("When this workspace opens")
                .font(DawnTextStyle.screenTitle)

            (Text("It ")

                + Text("should")
                .font(DawnTextStyle.emphasizedBody)
                .foregroundColor(DawnColors.emphasizedBody)

                + Text("?"))
                .font(DawnTextStyle.body)
                .foregroundColor(DawnColors.menuItemSecondaryForeground)

            VStack(spacing: 24) {
                ForEach(WorkspaceActivationPolicy.allCases, id: \.self) { policy in
                    policyButton(policy)
                }
            }

            Spacer()

            DButton(action: onFinish) {
                Text("Finish")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func policyButton(_ policy: WorkspaceActivationPolicy) -> some View {
        ActivationPolicyButton(
            policy: policy,
            isSelected: selectedPolicy == policy,
            action: { selectedPolicy = policy }
        )
    }
}
