import Foundation
import libdawn
import dawnLogging

@MainActor
protocol dawnAgentEventBusServicing: AnyObject {
    var bus: PaEventBus { get }

    func start()
    func stop()
}

@MainActor
final class dawnAgentEventBusService: dawnAgentEventBusServicing {
    private let runtime: dawnAgentEventBusRuntime
    private let readyNotifier: dawnAgentEventBusReadyNotifier

    var bus: PaEventBus { runtime.bus }

    init(
        runtime: dawnAgentEventBusRuntime = dawnAgentEventBusRuntime(),
        readyNotifier: dawnAgentEventBusReadyNotifier = dawnAgentEventBusReadyNotifier()
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
