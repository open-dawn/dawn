import Testing
import libdawn

@Suite("Event bus Mach service")
struct EventBusMachServiceTests {
    @Test("Official Release names stay inside the Developer ID app group")
    func officialReleaseNamesUseAppGroup() {
        #expect(
            EventBusMachService.officialAppGroupIdentifier == "2Q5VC69BFD.app.opendawn"
        )
        #expect(
            EventBusMachService.officialReleaseServiceName
                == "2Q5VC69BFD.app.opendawn.eventbus"
        )
        #expect(
            EventBusMachService.officialReleaseServiceName.hasPrefix(
                EventBusMachService.officialAppGroupIdentifier + "."
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
        #expect(
            EventBusMachService.releaseServiceName.hasPrefix(
                EventBusMachService.appGroupIdentifier + "."
            )
        )
        #endif
    }
}
