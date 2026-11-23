import libdawnUI
import SwiftUI

struct WorkspaceDetailTerminalCommandField: View {
    let command: String
    let interactionsDisabled: Bool
    let onCommandChange: (String) -> Void

    private static let placeholder = "#!/bin/env bash\necho \"testing\""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Terminal command")
                .font(DawnTextStyle.detailSectionLabel)
                .foregroundStyle(DawnColors.primaryForeground)

            TextField(
                Self.placeholder,
                text: Binding(
                    get: { command },
                    set: { onCommandChange($0) }
                ),
                axis: .vertical
            )
            .font(DawnTextStyle.detailField)
            .foregroundStyle(DawnColors.primaryForeground)
            .textFieldStyle(.plain)
            .lineLimit(3...8)
            .disabled(interactionsDisabled)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                DawnColors.activationPolicyBackground
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .accessibilityLabel("Terminal command")
        }
        .padding(.horizontal, 32)
    }
}
