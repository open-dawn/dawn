import Testing
import libdawn
@testable import dawnApp

@Suite("Settings event bus rendezvous")
struct SettingsEventBusRendezvousTests {
    @Test("Client uses the shared Mach service and ready ping")
    func clientUsesSharedRendezvous() {
        #expect(
            SettingsEventBusRendezvous.machServiceName == EventBusMachService.serviceName
        )
        #expect(
            SettingsEventBusRendezvous.readyNotification
                == EventBusMachService.readyNotification
        )
    }
}
