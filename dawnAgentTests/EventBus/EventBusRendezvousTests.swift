import Testing
import libdawn
@testable import dawnAgent

@Suite("Event bus rendezvous")
struct EventBusRendezvousTests {
    @Test("Host listens on the shared service name")
    func hostUsesSharedServiceName() {
        #expect(EventBusRendezvous.machServiceName == EventBusMachService.serviceName)
    }
}
