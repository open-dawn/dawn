import Foundation

/// Mach service the event bus listens on.
///
/// dawnAgent is a Login Item. launchd advertises a Mach service named as the
/// helper's bundle identifier after `SMAppService` registers it. dawnApp and
/// dawnAgent both use that name. App-group Mach services are for sandboxed
/// apps; DAWN is not sandboxed, so the team app-group name cannot complete an
/// XPC handshake.
public enum EventBusMachService {
    public static let serviceName = "app.opendawn.dawnAgent"
}
