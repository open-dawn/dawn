import Foundation

/// Shared DAWN process identities for the event-bus rendezvous.
///
/// Keep bundle ids, the Mach service name, and the ready ping here so host and
/// clients do not hardcode the same strings in several targets.
public enum EventBusMachService {
    public static let appBundleIdentifier = "app.opendawn.dawnApp"
    public static let agentBundleIdentifier = "app.opendawn.dawnAgent"

    /// launchd advertises this name after the login-item agent is registered.
    public static let serviceName = agentBundleIdentifier

    public static let readyNotificationName = "app.opendawn.dawnAgent.eventBusReady"
    public static let readyNotification = Notification.Name(readyNotificationName)
}
