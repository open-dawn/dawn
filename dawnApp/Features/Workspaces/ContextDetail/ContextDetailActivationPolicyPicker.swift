import libdawn
import libdawnUI
import SwiftUI

struct ContextDetailActivationPolicyPicker: View {
    let policy: WorkspaceActivationPolicy
    let interactionsDisabled: Bool
    let onPolicyChange: (WorkspaceActivationPolicy) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When switching to this context")
                .font(DawnTextStyle.detailSectionLabel)
                .foregroundStyle(DawnColors.primaryForeground)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(WorkspaceActivationPolicy.allCases, id: \.self) { candidate in
                    ActivationPolicyButton(
                        policy: candidate,
                        isSelected: policy == candidate,
                        action: { onPolicyChange(candidate) }
                    )
                    .disabled(interactionsDisabled)
                }
            }
        }
        .padding(.horizontal, 32)
    }
}
