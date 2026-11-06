import libdawn
import libdawnUI
import SwiftUI

struct ContextDetailActivationPolicyPicker: View {
    let policy: WorkspaceActivationPolicy
    let onPolicyChange: (WorkspaceActivationPolicy) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text("When switching to this context")
                .font(DawnTextStyle.sectionLabel)

            HStack(alignment: .top) {
                ForEach(WorkspaceActivationPolicy.allCases, id: \.self) { candidate in
                    DButton(style: .plain) {
                        onPolicyChange(candidate)
                    } content: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 2) {
                                Image(systemName: candidate.displaySymbol)
                                    .font(DawnTextStyle.primary)
                                    .foregroundStyle(
                                        policy == candidate ?
                                        DawnColors.primaryForeground :
                                            DawnColors.secondaryForeground
                                    )
                                Text(candidate.displayName)
                                    .font(DawnTextStyle.primary)
                                    .foregroundStyle(
                                        policy == candidate ?
                                        DawnColors.primaryForeground :
                                            DawnColors.secondaryForeground
                                    )
                            }
                            Text(candidate.displayDescription)
                                .font(DawnTextStyle.secondaryCaption)
                                .foregroundStyle(DawnColors.secondaryForeground)
                        }
                        .padding(24)
                        .frame( maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background {
                            DawnColors.secondaryBackground
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DawnColors.primaryForeground,
                                        lineWidth: policy == candidate ? 3 : 0)
                                .opacity(policy == candidate ? 1 : 0)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .animation(.spring, value: policy)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
    }
}
