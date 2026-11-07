import Testing
import libdawn
@testable import dawnAgent

@Suite("Event bus rendezvous")
struct EventBusRendezvousTests {
    @Test("Host uses the shared Mach service and ready ping")
    func hostUsesSharedRendezvous() {
        #expect(EventBusRendezvous.machServiceName == EventBusMachService.serviceName)
        #expect(EventBusRendezvous.readyNotification == EventBusMachService.readyNotification)
    }
}
