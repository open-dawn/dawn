import SwiftUI

struct AboutView: View {
    let content: AboutContent

    var body: some View {
        VStack(spacing: 24) {
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
}
