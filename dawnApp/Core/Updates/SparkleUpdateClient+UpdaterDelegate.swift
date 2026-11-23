import Foundation
import Sparkle

extension SparkleUpdateClient: SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        let trigger = consumeNextCheckTrigger()

        return Self.buildFeedURLString(
            hostBundle: hostBundle,
            userDefaults: userDefaults,
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersion,
            trigger: trigger
        )
    }

    static func buildFeedURLString(
        hostBundle: Bundle,
        userDefaults: UserDefaults,
        operatingSystemVersion: OperatingSystemVersion,
        trigger: String
    ) -> String? {
        guard let baseFeedURL = hostBundle.object(
            forInfoDictionaryKey: "SUFeedURL"
        ) as? String,
        var components = URLComponents(string: baseFeedURL)
        else {
            return nil
        }

        let identity = UpdateInstallationIdentity.loadOrCreate(
            userDefaults: userDefaults
        )
        let shortVersion = (
            hostBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        ) ?? "unknown"
        let buildVersion = (
            hostBundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        ) ?? "unknown"
        let osVersion = [
            operatingSystemVersion.majorVersion,
            operatingSystemVersion.minorVersion,
            operatingSystemVersion.patchVersion,
        ]
        .map(String.init)
        .joined(separator: ".")

        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "client", value: "sparkle"))
        items.append(URLQueryItem(name: "uid", value: identity.installationID))
        items.append(URLQueryItem(name: "v", value: shortVersion))
        items.append(URLQueryItem(name: "build", value: buildVersion))
        items.append(URLQueryItem(name: "os", value: osVersion))
        items.append(URLQueryItem(name: "trigger", value: trigger))
        components.queryItems = items

        return components.url?.absoluteString
    }
}
