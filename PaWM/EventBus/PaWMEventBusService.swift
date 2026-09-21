import Foundation
import PaEventKit

@MainActor
final class PaWMEventBusService {
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
        _ = runtime.start()
        readyNotifier.postReady()
    }

    func stop() {
        runtime.stop()
    }
}
