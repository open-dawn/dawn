import Foundation
@testable import PaEventKit

@MainActor
final class PingResponder: Listener {
    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        guard case .debugPing = event else { return }
        reply?(.debugPong(PaDebugPongEvent(message: "remote-ok")))
    }
}

@MainActor
final class RecordingListener: Listener {
    private(set) var events: [PaEvent] = []

    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        events.append(event)
    }
}

func waitUntilConnected(
    _ bus: PaRemoteEventBus,
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
    _ bus: PaRemoteEventBus,
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
