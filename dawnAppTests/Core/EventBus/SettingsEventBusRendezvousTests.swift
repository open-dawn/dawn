import Testing
import libdawn
@testable import dawnApp

@Suite("Settings event bus rendezvous")
struct SettingsEventBusRendezvousTests {
    @Test("Client connects to the agent bundle id")
    func clientUsesAgentBundleIdentifier() {
        #expect(
            SettingsEventBusRendezvous.machServiceName == EventBusMachService.serviceName
        )
        #expect(
            SettingsEventBusRendezvous.machServiceName == "app.opendawn.dawnAgent"
        )
    }
}
