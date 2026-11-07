import Testing
import libdawn

@Suite("Event bus Mach service")
struct EventBusMachServiceTests {
    @Test("Keeps the DAWN process identities in one place")
    func keepsProjectIdentities() {
        #expect(EventBusMachService.appBundleIdentifier == "app.opendawn.dawnApp")
        #expect(EventBusMachService.agentBundleIdentifier == "app.opendawn.dawnAgent")
        #expect(EventBusMachService.serviceName == EventBusMachService.agentBundleIdentifier)
        #expect(
            EventBusMachService.readyNotificationName
                == "app.opendawn.dawnAgent.eventBusReady"
        )
        #expect(
            EventBusMachService.readyNotification.rawValue
                == EventBusMachService.readyNotificationName
        )
    }
}
