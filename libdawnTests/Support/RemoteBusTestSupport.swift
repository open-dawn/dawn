import Foundation
@testable import libdawn

@MainActor
final class PingResponder: Listener {
    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?) {
        guard case .debugPing = event else { return }
        reply?(.debugPong(DebugPongEvent(message: "remote-ok")))
    }
}

@MainActor
final class RecordingListener: Listener {
    private(set) var events: [Event] = []

    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?) {
        events.append(event)
    }
}

func waitUntilConnected(
    _ bus: RemoteEventBus,
    timeout: Duration = .seconds(2)
) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if bus.isConnected {
            return true
        }
        try? await Task.sleep(for: .milliseconds(50))
    }
    return bus.isConnected
}

func waitUntilDisconnected(
    _ bus: RemoteEventBus,
    timeout: Duration = .seconds(2)
) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if !bus.isConnected {
            return true
        }
        try? await Task.sleep(for: .milliseconds(50))
    }
    return !bus.isConnected
}
