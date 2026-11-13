import Foundation

public enum EventBusMachService {
    public static let appBundleIdentifier = "app.opendawn.dawnApp"
    public static let agentBundleIdentifier = "app.opendawn.dawnAgent"

    public static let serviceName = agentBundleIdentifier

    /// Debug builds use distributed notifications as a lightweight rendezvous
    /// so the app and agent can both be launched directly from Xcode.
    public static let developmentServiceName = "app.opendawn.dawnAgent.debugEventBus"

    public static let readyNotificationName = "app.opendawn.dawnAgent.eventBusReady"
    public static let readyNotification = Notification.Name(readyNotificationName)
}
