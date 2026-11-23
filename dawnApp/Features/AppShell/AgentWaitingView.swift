import libdawnUI
import SwiftUI

struct AgentWaitingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.regular)

            Text("Waiting for DAWN Agent…")
                .font(DawnTextStyle.sidebarAction)
                .foregroundStyle(DawnColors.sidebarMeta)
                .accessibilityAddTraits(.updatesFrequently)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Waiting for DAWN Agent")
    }
}

#Preview {
    AgentWaitingView()
        .frame(width: 530, height: 680)
        .background(DawnColors.primaryBackground)
        .preferredColorScheme(.dark)
}
