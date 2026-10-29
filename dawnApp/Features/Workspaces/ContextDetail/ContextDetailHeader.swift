import libdawnUI
import SwiftUI

struct ContextDetailHeader: View {
    let name: String
    let symbol: String
    let isActive: Bool
    let interactionsDisabled: Bool
    let onActivate: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            Label(name, systemImage: symbol)
                .contentTransition(.symbolEffect)
                .font(DawnTextStyle.screenTitle)
                .animation(.spring, value: symbol)

            Spacer()

            if isActive {
                // swiftlint:disable:next todo
                // FIXME: Stop has no action yet. There is no stop event on the agent.
                DButton(style: .danger) {
                } content: {
                    Text("Stop")
                } leading: {
                    Image(systemName: "stop.fill")
                }
                .disabled(interactionsDisabled)
            } else {
                DButton(style: .success) {
                    onActivate()
                } content: {
                    Text("Activate")
                } leading: {
                    Image(systemName: "play.fill")
                }
                .disabled(interactionsDisabled)
            }

            // swiftlint:disable:next todo
            // FIXME: This should be a menu with Delete (trash) and Archive (shippingbox).
            DButton(style: .icon) {

            } content: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
    }
}
