//
//  ContextOpeningBehaviorStepView.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/10/26.
//

import libdawn
import SwiftUI

struct ContextOpeningBehaviorStepView: View {
    @Binding var selectedPolicy: WorkspaceActivationPolicy

    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 42) {
            ContextCreationStepHeader(
                title: "When this workspace opens...",
                subtitle: "it should?",
                style: .compact
            )

            VStack(spacing: 24) {
                ForEach(WorkspaceActivationPolicy.allCases, id: \.self) { policy in
                    policyButton(policy)
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            DButton(action: onFinish) {
                Text("Finish")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func policyButton(_ policy: WorkspaceActivationPolicy) -> some View {
        let isSelected = selectedPolicy == policy

        return DButton(
            style: .plain,
            action: {
                selectedPolicy = policy
            },
            content: {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(DawnTextStyle.selectionIcon)
                        .foregroundStyle(DawnColors.primaryForeground)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(policy.displayName)
                            .font(DawnTextStyle.optionTitle)
                            .foregroundStyle(DawnColors.primaryForeground)

                        Text(policy.displayDescription)
                            .font(DawnTextStyle.secondaryCaption)
                            .foregroundStyle(DawnColors.menuItemSecondaryForeground)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()
                }
            }
        )
        .accessibilityLabel(policy.displayName)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
