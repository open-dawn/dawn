import Foundation
import libdawn

enum AgentStatus {
    static func query() async throws -> String {
        try message(try await AgentSession.ask(.debugPing(DebugPingEvent())))
    }

    static func query(bus: RemoteEventBus) async throws -> String {
        defer { bus.disconnect() }
        return try message(
            try await AgentSession.ask(.debugPing(DebugPingEvent()), bus: bus)
        )
    }

    private static func message(_ reply: Event) throws -> String {
        guard case let .debugPong(pong) = reply else {
            throw AgentError.unexpectedResponse(reply.kind)
        }

        return pong.message
    }
}
