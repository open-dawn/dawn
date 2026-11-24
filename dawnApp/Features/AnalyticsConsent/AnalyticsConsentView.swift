import libdawnUI
import SwiftUI

struct AnalyticsConsentView: View {
    let isSubmitting: Bool
    let errorMessage: String?
    let onChoose: (Bool) -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(DawnColors.primaryForeground)
                    .accessibilityHidden(true)

                Text("Help improve Dawn")
                    .font(DawnTextStyle.confirmationTitle)
                    .dawnZainOpticalAlignment()
                    .foregroundStyle(DawnColors.primaryForeground)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Text(
                    "Dawn features basic, anonymous analytics used solely for improving the app."
                )
                .font(DawnTextStyle.body)
                .foregroundStyle(DawnColors.primaryForeground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                Text(
                    "Would you like to enable analytics? You can change your mind anytime in the Settings menu."
                )
                .font(DawnTextStyle.secondaryCaption)
                .foregroundStyle(DawnColors.secondaryForeground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(DawnTextStyle.secondaryCaption)
                    .foregroundStyle(DawnColors.dangerForeground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                DButton(style: .secondary) {
                    onChoose(false)
                } content: {
                    Text("Disable")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isSubmitting)
                .frame(maxWidth: .infinity)

                DButton(style: .primary) {
                    onChoose(true)
                } content: {
                    Text("Enable")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isSubmitting)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(28)
        .frame(width: 400)
        .background {
            DawnColors.primaryBackground
                .ignoresSafeArea()
        }
        .presentationBackground(DawnColors.primaryBackground)
        .interactiveDismissDisabled(true)
    }
}

#Preview {
    AnalyticsConsentView(
        isSubmitting: false,
        errorMessage: nil,
        onChoose: { _ in }
    )
}
