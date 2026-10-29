import libdawnUI
import SwiftUI

struct ContextDetailNameField: View {
    let name: String
    let onNameChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text("Name")
                .font(DawnTextStyle.sectionLabel)

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
        }
    }
}
