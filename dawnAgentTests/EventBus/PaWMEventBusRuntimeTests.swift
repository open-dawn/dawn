import Foundation
import libdawn
import Testing

@testable import dawnAgent

@MainActor
@Suite("dawnAgentEventBusRuntime")
struct dawnAgentEventBusRuntimeTests {
    @Test("Start yields an endpoint a remote bus can use")
    func startYieldsUsableEndpoint() async throws {
        let runtime = dawnAgentEventBusRuntime(machServiceName: nil)
        defer { runtime.stop() }

        guard let endpoint = runtime.start() else {
            Issue.record("Expected anonymous XPC listener endpoint")
            return
        }

        let remoteBus = PaRemoteEventBus(
            transport: XPCRemoteEventTransportClient(endpoint: endpoint)
        )
        defer { remoteBus.disconnect() }

        var connected = remoteBus.isConnected
        for _ in 0..<40 where !connected {
            try await Task.sleep(for: .milliseconds(50))
            connected = remoteBus.isConnected
        }
        #expect(connected)

        do {
            _ = try await remoteBus.ask(
                .debugPing(PaDebugPingEvent()),
                timeout: .milliseconds(200)
            )
            Issue.record("Expected ask to fail with noHandler")
        } catch let error as PaEventAskError {
            #expect(error == .noHandler)
        } catch {
            let nsError = error as NSError
            #expect(nsError.domain == "libdawn.PaEventAskError")
            #expect(nsError.code == 0)
        }
    }

    @Test("Host publish is received by a remote listener")
    func hostPublishReachesRemoteListener() async throws {
        let runtime = dawnAgentEventBusRuntime(machServiceName: nil)
        defer { runtime.stop() }

        guard let endpoint = runtime.start() else {
            Issue.record("Expected anonymous XPC listener endpoint")
            return
        }

        let remoteBus = PaRemoteEventBus(
            transport: XPCRemoteEventTransportClient(endpoint: endpoint)
        )
        defer { remoteBus.disconnect() }

        let listener = RecordingListener()
        remoteBus.addListener(listener, kinds: [.switchSpace])
        try await Task.sleep(for: .milliseconds(200))

        let event = PaEvent.switchSpace(PaSwitchSpaceEvent(spaceIndex: 4))
        runtime.bus.publish(event)

        try await Task.sleep(for: .milliseconds(200))

        #expect(listener.events == [event])
    }

    @Test("Stop invalidates clients on the old endpoint")
    func stopInvalidatesOldEndpoint() async throws {
        let runtime = dawnAgentEventBusRuntime(machServiceName: nil)

        guard let endpoint = runtime.start() else {
            Issue.record("Expected anonymous XPC listener endpoint")
            runtime.stop()
            return
        }

        let remoteBus = PaRemoteEventBus(
            transport: XPCRemoteEventTransportClient(endpoint: endpoint)
        )
        defer { remoteBus.disconnect() }

        var connected = remoteBus.isConnected
        for _ in 0..<40 where !connected {
            try await Task.sleep(for: .milliseconds(50))
            connected = remoteBus.isConnected
        }
        #expect(connected)

        runtime.stop()

        var disconnected = remoteBus.isConnected == false
        for _ in 0..<10 where !disconnected {
            try await Task.sleep(for: .milliseconds(100))
            disconnected = remoteBus.isConnected == false
        }

        if disconnected {
            #expect(remoteBus.isConnected == false)
            return
        }

        do {
            _ = try await remoteBus.ask(
                .debugPing(PaDebugPingEvent()),
                timeout: .milliseconds(200)
            )
            Issue.record("Expected ask to fail after stop")
        } catch {
            // XPC invalidation may surface as notConnected or a transport NSError.
        }
    }

    @Test("Stop can be called safely more than once")
    func stopCanBeCalledMultipleTimes() {
        let runtime = dawnAgentEventBusRuntime(machServiceName: nil)
        _ = runtime.start()

        runtime.stop()
        runtime.stop()
    }
}
