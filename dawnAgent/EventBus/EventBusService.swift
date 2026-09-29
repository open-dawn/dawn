import Foundation
import libdawn
import dawnLogging

@MainActor
protocol EventBusServicing: AnyObject {
    var bus: EventBus { get }

    func start()
    func stop()
}

@MainActor
final class EventBusService: EventBusServicing {
    private let runtime: EventBusRuntime
    private let readyNotifier: EventBusReadyNotifier

    var bus: EventBus { runtime.bus }

    init(
        runtime: EventBusRuntime = EventBusRuntime(),
        readyNotifier: EventBusReadyNotifier = EventBusReadyNotifier()
    ) {
        self.runtime = runtime
        self.readyNotifier = readyNotifier
    }

    func start() {
        #log(
            "Starting dawnAgent XPC runtime",
            level: .info,
            category: .eventBus
        )

        _ = runtime.start()

        #log(
            "dawnAgent XPC runtime start requested",
            level: .info,
            category: .eventBus
        )

        readyNotifier.postReady()

        #log(
            "Posted dawnAgent ready notification",
            level: .info,
            category: .eventBus
        )
    }

    func stop() {
        runtime.stop()
    }
}
