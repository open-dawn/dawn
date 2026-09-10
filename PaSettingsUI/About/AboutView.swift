import SwiftUI

struct AboutView: View {
    @Environment(PaSettingsEventBusService.self) private var eventBusService

    let content: AboutContent

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                if eventBusService.connectionState == .connecting {
                    ProgressView()
                }

                Text(connectionLabel)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0){
                Text("Copyright: ")
                Text(verbatim: content.metadata.copyright)
                    .bold()
            }

            HStack(spacing: 0) {
                Text("License: ")
                Text(verbatim: content.metadata.license)
                    .bold()
            }

            HStack(spacing: 0) {
                Text("Version: ")
                Text(verbatim: content.appVersion)
                    .bold()
                Text(" - ")
                Link(
                    content.metadata.commit.displayName,
                    destination: content.metadata.commit.url
                )
            }

            HStack(spacing: 0) {
                Link(
                    "Privacy Policy",
                    destination: content.metadata.privacyPolicyURL
                )
                Text(" - ")
                Link(
                    "Terms of Use",
                    destination: content.metadata.termsOfUseURL
                )
            }
        }
    }

    private var connectionLabel: String {
        switch eventBusService.connectionState {
        case .disconnected:
            "Not Connected"
        case .connecting:
            "Connecting..."
        case .connected:
            "Connected"
        }
    }
}
