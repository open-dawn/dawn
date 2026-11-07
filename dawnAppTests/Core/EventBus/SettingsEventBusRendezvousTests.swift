import Testing
import libdawn
@testable import dawnApp

@Suite("Settings event bus rendezvous")
struct SettingsEventBusRendezvousTests {
    @Test("Client connects to the shared service name")
    func clientUsesSharedServiceName() {
        #expect(
            SettingsEventBusRendezvous.machServiceName == EventBusMachService.serviceName
        )
    }
}
