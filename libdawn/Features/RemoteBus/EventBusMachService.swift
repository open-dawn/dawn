import Foundation

/// Mach service the event bus listens on.
///
/// Release builds use the signing team's app group. The app and agent Info.plist
/// keys `DawnAppGroupIdentifier` and `DawnEventBusMachService` expand
/// `$(TeamIdentifierPrefix)` at build time, so a local Apple Development team
/// and the official Developer ID team both work. Debug builds keep the agent
/// bundle id: those builds are not signed for the team app group.
public enum EventBusMachService {
    public static let appGroupInfoKey = "DawnAppGroupIdentifier"
    public static let machServiceInfoKey = "DawnEventBusMachService"
    public static let officialAppGroupIdentifier = "2Q5VC69BFD.app.opendawn"
    public static let officialReleaseServiceName = "2Q5VC69BFD.app.opendawn.eventbus"
    public static let debugServiceName = "app.opendawn.dawnAgent"

    public static var appGroupIdentifier: String {
        infoString(for: appGroupInfoKey) ?? officialAppGroupIdentifier
    }

    public static var releaseServiceName: String {
        infoString(for: machServiceInfoKey) ?? officialReleaseServiceName
    }

    public static var serviceName: String {
        #if DEBUG
        debugServiceName
        #else
        releaseServiceName
        #endif
    }

    private static func infoString(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else {
            return nil
        }

        return trimmed
    }
}
