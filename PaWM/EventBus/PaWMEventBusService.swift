import Foundation
import PaEventKit
import PaLogging

@MainActor
protocol PaWMEventBusServicing: AnyObject {
    var bus: PaEventBus { get }

    func start()
    func stop()
}

@MainActor
final class PaWMEventBusService: PaWMEventBusServicing {
    private let runtime: PaWMEventBusRuntime
    private let readyNotifier: PaWMEventBusReadyNotifier

    var bus: PaEventBus { runtime.bus }

    init(
        runtime: PaWMEventBusRuntime = PaWMEventBusRuntime(),
        readyNotifier: PaWMEventBusReadyNotifier = PaWMEventBusReadyNotifier()
    ) {
        self.runtime = runtime
        self.readyNotifier = readyNotifier
    }

    func start() {
        #log(
            "Starting PaWM XPC runtime",
            level: .info,
            category: .eventBus
        )

        _ = runtime.start()

        #log(
            "PaWM XPC runtime start requested",
            level: .info,
            category: .eventBus
        )

        readyNotifier.postReady()

        #log(
            "Posted PaWM ready notification",
            level: .info,
            category: .eventBus
        )
    }

    func stop() {
        runtime.stop()
    }
}
