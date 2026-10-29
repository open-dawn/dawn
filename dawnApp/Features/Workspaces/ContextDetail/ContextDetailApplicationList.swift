import libdawn
import libdawnUI
import SwiftUI

struct ContextDetailApplicationList: View {
    let applications: [WorkspaceApplication]

    var body: some View {
        // swiftlint:disable:next todo
        // FIXME: Application rows and the add button are not implemented yet.
        VStack(alignment: .leading) {
            Text("Applications")
                .font(DawnTextStyle.sectionLabel)

            FlowLayout(spacing: 8) {
                ForEach(applications) { app in
                    DButton(style: .plain) {

                    } content: {
                        HStack {
                            if let appPath = app.applicationURL?.path(percentEncoded: false) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: appPath))
                            } else {
                                Image(systemName: "questionmark.square")
                            }
                            Text(app.displayName)
                                .font(DawnTextStyle.secondary)

                            Image(systemName: "chevron.down")
                                .padding(.leading, 16)
                        }
                        .padding(8)
                        .background {
                            DawnColors.secondaryBackground
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                DButton(style: .plain) {

                } content: {
                    Image(systemName: "plus")
                        .padding(8)
                        .background {
                            DawnColors.secondaryBackground
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(9.5)
                }

                if applications.isEmpty {
                    Text("No applications added to this context.")
                        .font(DawnTextStyle.primary)
                        .foregroundStyle(DawnColors.secondaryForeground)
                        .padding()
                }
            }
        }
        .padding(.horizontal, 32)
    }
}
