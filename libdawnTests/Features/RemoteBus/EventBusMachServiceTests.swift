import Testing
import libdawn

@Suite("Event bus Mach service")
struct EventBusMachServiceTests {
    @Test("Release service name is inside the Developer ID app group")
    func releaseServiceNameUsesAppGroup() {
        #expect(EventBusMachService.appGroupIdentifier == "2Q5VC69BFD.app.opendawn")
        #expect(
            EventBusMachService.releaseServiceName
                == "2Q5VC69BFD.app.opendawn.eventbus"
        )
        #expect(
            EventBusMachService.releaseServiceName.hasPrefix(
                EventBusMachService.appGroupIdentifier + "."
            )
        )
    }

    @Test("Debug service name stays the agent bundle id")
    func debugServiceNameStaysBundleIdentifier() {
        #expect(EventBusMachService.debugServiceName == "app.opendawn.dawnAgent")
    }

    @Test("The active service name matches this build configuration")
    func serviceNameMatchesConfiguration() {
        #if DEBUG
        #expect(EventBusMachService.serviceName == EventBusMachService.debugServiceName)
        #else
        #expect(EventBusMachService.serviceName == EventBusMachService.releaseServiceName)
        #endif
    }
}
