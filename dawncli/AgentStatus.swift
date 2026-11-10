import Foundation
import libdawn

enum AgentStatus {
    static func query() async throws -> String {
        let bus = RemoteEventBus(
            transport: XPCRemoteEventTransportClient(
                machServiceName: EventBusMachService.serviceName
            )
        )
        return try await query(bus: bus)
    }

    static func query(bus: RemoteEventBus) async throws -> String {
        defer { bus.disconnect() }

        try await connect(bus)

        let reply = try await requestStatus(bus)
        guard case let .debugPong(pong) = reply else {
            throw AgentStatusError.unexpectedResponse(reply.kind)
        }

        return pong.message
    }

    private static func connect(_ bus: RemoteEventBus) async throws {
        guard !bus.isConnected else { return }

        do {
            try await bus.attemptReconnect()
        } catch {
            throw AgentStatusError(error)
        }
    }

    private static func requestStatus(_ bus: RemoteEventBus) async throws -> Event {
        do {
            return try await bus.ask(.debugPing(DebugPingEvent()))
        } catch {
            throw AgentStatusError(error)
        }
    }
}
