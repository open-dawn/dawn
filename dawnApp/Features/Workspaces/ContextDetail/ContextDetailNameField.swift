import libdawnUI
import SwiftUI

struct ContextDetailNameField: View {
    let name: String
    var validationMessage: String?
    let onNameChange: (String) -> Void

    @State private var isValidationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(DawnTextStyle.sectionLabel)

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
        HStack {
            Image(systemName: "textformat")
                .font(DawnTextStyle.textFieldSecondaryIcon)
                .foregroundStyle(DawnColors.secondaryForeground)

            TextField("Name", text: Binding(get: {
                name
            }, set: { newName in
                onNameChange(newName)
            }))
            .textFieldStyle(.plain)
        }
        .padding(8)
        .background {
            DawnColors.textFieldInset
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
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
