import libdawnUI
import SwiftUI

struct EmptyWorkspacesView: View {
    let onCreateWorkspace: () -> Void
    let interactionsDisabled: Bool

    var body: some View {
        VStack(spacing: 24) {
            DuskSleepy.image(height: 92)

            VStack(spacing: 4) {
                Text("No workspaces yet")
                    .font(DawnTextStyle.noWorkspaceTitle)
                    .dawnZainOpticalAlignment()
                    .foregroundStyle(DawnColors.sidebarMeta)

                (
                    Text("Create a ")
                        .font(DawnTextStyle.noWorkspaceBody)
                    + Text("new one")
                        .font(DawnTextStyle.noWorkspaceBodyEmphasis)
                    + Text(" to start organizing")
                        .font(DawnTextStyle.noWorkspaceBody)
                )
                .foregroundStyle(DawnColors.sidebarMeta)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .onTapGesture {
                    guard !interactionsDisabled else {
                        return
                    }

                    onCreateWorkspace()
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Creates a new workspace")
                .disabled(interactionsDisabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 33)
    }
}

#Preview {
    EmptyWorkspacesView(onCreateWorkspace: {}, interactionsDisabled: false)
        .frame(width: 530, height: 680)
        .background(DawnColors.primaryBackground)
        .preferredColorScheme(.dark)
}
