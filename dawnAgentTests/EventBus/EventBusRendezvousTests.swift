import Testing
import libdawn
@testable import dawnAgent

@Suite("Event bus rendezvous")
struct EventBusRendezvousTests {
    @Test("Host listens on the agent bundle id")
    func hostUsesAgentBundleIdentifier() {
        #expect(EventBusRendezvous.machServiceName == EventBusMachService.serviceName)
        #expect(EventBusRendezvous.machServiceName == "app.opendawn.dawnAgent")
    }
}
