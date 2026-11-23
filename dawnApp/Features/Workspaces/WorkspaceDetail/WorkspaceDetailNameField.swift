import libdawnUI
import SwiftUI

struct WorkspaceDetailNameField: View {
    let name: String
    var validationMessage: String?
    let interactionsDisabled: Bool
    let onNameChange: (String) -> Void

    @State private var isValidationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Name")
                .font(DawnTextStyle.detailSectionLabel)
                .foregroundStyle(DawnColors.primaryForeground)

            nameInput
                .popover(isPresented: $isValidationPresented, arrowEdge: .bottom) {
                    validationPopover
                }
        }
        .onChange(of: validationMessage, initial: true) { _, message in
            isValidationPresented = message != nil
        }
    }

    private var nameInput: some View {
        TextField(
            "Workspace name",
            text: Binding(
                get: { name },
                set: { onNameChange($0) }
            ),
            prompt: Text("Workspace name")
                .foregroundColor(DawnColors.detailForeground)
        )
        .font(DawnTextStyle.detailField)
        .foregroundStyle(DawnColors.primaryForeground)
        .textFieldStyle(.plain)
        .disabled(interactionsDisabled)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            DawnColors.activationPolicyBackground
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    validationMessage == nil ? Color.clear : DawnColors.dangerForeground,
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
        .accessibilityHint(validationMessage ?? "")
    }

    private var validationPopover: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .accessibilityHidden(true)

            Text(validationMessage ?? "")
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .font(DawnTextStyle.caption)
        .foregroundStyle(DawnColors.dangerForeground)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 240, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
