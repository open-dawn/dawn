import Foundation
import libdawn

@MainActor
final class RecordingListener: Listener {
    private(set) var events: [Event] = []

    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?) {
        events.append(event)
    }
}
