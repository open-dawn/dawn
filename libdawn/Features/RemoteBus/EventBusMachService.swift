import Foundation

public enum EventBusMachService {
    public static let appBundleIdentifier = "app.opendawn.dawnApp"
    public static let agentBundleIdentifier = "app.opendawn.dawnAgent"

    public static let serviceName = agentBundleIdentifier

    public static let readyNotificationName = "app.opendawn.dawnAgent.eventBusReady"
    public static let readyNotification = Notification.Name(readyNotificationName)
}
