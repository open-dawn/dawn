import Testing
import libdawn

@Suite("Event bus Mach service")
struct EventBusMachServiceTests {
    @Test("Service name is the dawnAgent bundle id")
    func serviceNameIsAgentBundleIdentifier() {
        #expect(EventBusMachService.serviceName == "app.opendawn.dawnAgent")
    }
}
