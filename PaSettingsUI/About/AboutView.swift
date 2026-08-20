import SwiftUI

struct AboutView: View {
    private let copyright: String = "PineApple INC 2026"
    private let license: String = "GNU GENERAL PUBLIC LICENSE"
    private let appVersion: String = "0.0.0"
    private let lastCommit: String = "6e5174f (stable)"
    private let lastCommitURL: String = "https://github.com/PineAppleIncOS/pineapplewm/commit/6e5174fc9a701ecdfa6269ead19ce6a49cc3f92f"
    private let privacyPolicyURL: String = "https://github.com/PineAppleIncOS/pineapplewm"
    private let termsOfUseURL: String = "https://github.com/PineAppleIncOS/pineapplewm"

    var body: some View {
        VStack(spacing: 24) {
            Text(.init("Copyright: **\(self.copyright)**"))
            Text(.init("License: **\(self.license)**"))
            Text(.init("Version **\(self.appVersion)** - [\(self.lastCommit)](\(self.termsOfUseURL))"))
            Text(.init("[Privacy of Policy](\(self.privacyPolicyURL)) - [Terms of Use](\(self.termsOfUseURL))"))
        }
    }
}
