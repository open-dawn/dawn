//
//  ContextOpeningBehaviorStepView.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/10/26.
//

import SwiftUI
import libdawnUI

struct ContextOpeningBehaviorStepView: View {
    @Binding var selectedBehavior: ContextOpeningBehavior

    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 42) {
            ContextCreationStepHeader(
                title: "When this workspace opens...",
                subtitle: "it should?",
                style: .compact
            )

            VStack(spacing: 24) {
                ForEach(ContextOpeningBehavior.allCases, id: \.self) { behavior in
                    behaviorButton(behavior)
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

    private func behaviorButton(_ behavior: ContextOpeningBehavior) -> some View {
        let isSelected = selectedBehavior == behavior

        return DButton(
            style: .plain,
            action: {
                selectedBehavior = behavior
            },
            content: {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(DawnTextStyle.selectionIcon)
                        .foregroundStyle(DawnColors.primaryForeground)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(behavior.title)
                            .font(DawnTextStyle.optionTitle)
                            .foregroundStyle(DawnColors.primaryForeground)

                        Text(behavior.detail)
                            .font(DawnTextStyle.secondaryCaption)
                            .foregroundStyle(DawnColors.menuItemSecondaryForeground)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()
                }
            }
        )
        .accessibilityLabel(behavior.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
