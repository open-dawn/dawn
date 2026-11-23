//
//  ActivationPolicyButton.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/11/26.
//

import SwiftUI
import libdawn

public struct ActivationPolicyButton: View {
    public let policy: WorkspaceActivationPolicy
    public let isSelected: Bool
    public let action: () -> Void

    public init(
        policy: WorkspaceActivationPolicy,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.policy = policy
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        DButton(
            style: .plain,
            action: action
        ) {
            label
        }
        .animation(
            .easeOut(duration: 0.12),
            value: isSelected
        )
        .accessibilityLabel(policy.displayName)
        .accessibilityValue(
            isSelected ? "Selected" : "Not selected"
        )
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )
    }

    private var label: some View {
        HStack(spacing: 8) {
            Image(systemName: policy.displaySymbol)
                .font(DawnTextStyle.activationPolicyIcon)
                .foregroundStyle(titleColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 0) {
                Text(policy.displayName)
                    .font(DawnTextStyle.activationPolicyTitle)
                    .foregroundStyle(titleColor)

                Text(policy.displayDescription)
                    .font(DawnTextStyle.activationPolicyDescription)
                    .foregroundStyle(descriptionColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            minHeight: 64,
            alignment: .leading
        )
        .background(
            backgroundColor,
            in: RoundedRectangle(cornerRadius: 4)
        )
        .contentShape(
            RoundedRectangle(cornerRadius: 4)
        )
    }

    private var backgroundColor: Color {
        isSelected
            ? DawnColors.activationPolicySelectedBackground
            : DawnColors.activationPolicyBackground
    }

    private var titleColor: Color {
        isSelected
            ? DawnColors.activationPolicySelectedTitle
            : DawnColors.activationPolicyTitle
    }

    private var descriptionColor: Color {
        isSelected
            ? DawnColors.activationPolicySelectedDescription
            : DawnColors.activationPolicyDescription
    }
}
