import Foundation
import Testing
@testable import libdawn

@Suite("PaEventServer")
struct PaEventServerTests {
    @Test("host ask fails when only a remote is connected")
    func throwsNoHandlerWhenOnlyRemoteIsConnected() async {
        let hostBus = PaEventBus()
        let eventServer = PaEventServer(bus: hostBus)
        let link = LoopbackEventLink()
        eventServer.attach(link.server)

        await #expect(throws: PaEventAskError.noHandler) {
            _ = try await hostBus.ask(.debugPing(PaDebugPingEvent()), timeout: .milliseconds(100))
        }

        eventServer.stop()
    }

    @Test("host ask fails even if remote subscribed to the kind")
    @MainActor
    func throwsNoHandlerWhenRemoteSubscribedToSameKind() async {
        let hostBus = PaEventBus()
        let eventServer = PaEventServer(bus: hostBus)
        let link = LoopbackEventLink()
        eventServer.attach(link.server)

        let remoteBus = PaRemoteEventBus(transport: link.client)
        let listener = RecordingListener()
        remoteBus.addListener(listener, kinds: [.debugPing])

        await #expect(throws: PaEventAskError.noHandler) {
            _ = try await hostBus.ask(.debugPing(PaDebugPingEvent()), timeout: .milliseconds(100))
        }

        remoteBus.disconnect()
        eventServer.stop()
    }
}
