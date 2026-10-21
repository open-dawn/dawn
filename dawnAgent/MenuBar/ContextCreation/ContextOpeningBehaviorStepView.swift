//
//  ContextOpeningBehaviorStepView.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/10/26.
//

import SwiftUI

struct ContextOpeningBehaviorStepView: View {
    @Binding var selectedBehavior: ContextOpeningBehavior

    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 42) {
            VStack(spacing: 6) {
                Text("When this workspace opens...")
                    .font(.system(size: 18, weight: .bold))

                Text("it should?")
                    .font(.system(size: 14))
            }
            .multilineTextAlignment(.center)

            VStack(spacing: 24) {
                ForEach(ContextOpeningBehavior.allCases) { behavior in
                    behaviorButton(behavior)
                }
            }
            .padding(.horizontal, 28)

            Button(action: onFinish) {
                Text("Finish")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
        }
    }

    private func behaviorButton(_ behavior: ContextOpeningBehavior) -> some View {
        let isSelected = selectedBehavior == behavior

        return Button {
            selectedBehavior = behavior
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 6) {
                    Text(behavior.title)
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(.primary)

                    Text(behavior.detail)
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(behavior.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
