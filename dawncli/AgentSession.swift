import Foundation
import libdawn

enum AgentSession {
    static func ask(_ event: Event) async throws -> Event {
        let bus = makeBus()
        defer { bus.disconnect() }
        return try await ask(event, bus: bus)
    }

    static func ask(_ event: Event, bus: RemoteEventBus) async throws -> Event {
        try await connect(bus)
        do {
            return try await bus.ask(event)
        } catch {
            throw AgentError(error)
        }
    }

    static func perform<T: Sendable>(
        _ body: @Sendable (
            _ ask: @escaping @Sendable (Event) async throws -> Event
        ) async throws -> T
    ) async throws -> T {
        let bus = makeBus()
        defer { bus.disconnect() }
        try await connect(bus)

        return try await body { event in
            do {
                return try await bus.ask(event)
            } catch {
                throw AgentError(error)
            }
        }
    }

    private static func makeBus() -> RemoteEventBus {
        RemoteEventBus(
            transport: XPCRemoteEventTransportClient(
                machServiceName: EventBusMachService.serviceName
            )
        )
    }

    private static func connect(_ bus: RemoteEventBus) async throws {
        guard !bus.isConnected else { return }

        do {
            try await bus.attemptReconnect()
        } catch {
            throw AgentError(error)
        }
    }
}
