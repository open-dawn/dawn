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
