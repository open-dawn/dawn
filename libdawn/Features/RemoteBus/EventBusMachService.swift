import Foundation

/// Mach service the event bus listens on.
///
/// Release builds are signed with Developer ID team `2Q5VC69BFD`. The service
/// name sits inside that team's app group, which macOS authorizes from the
/// signature without a provisioning profile. Debug builds keep the agent
/// bundle id: Xcode does not sign them with that Developer ID team, so the
/// team app group would not be honored.
public enum EventBusMachService {
    public static let appGroupIdentifier = "2Q5VC69BFD.app.opendawn"
    public static let releaseServiceName = "2Q5VC69BFD.app.opendawn.eventbus"
    public static let debugServiceName = "app.opendawn.dawnAgent"

    public static var serviceName: String {
        #if DEBUG
        debugServiceName
        #else
        releaseServiceName
        #endif
    }
}
