import Foundation

public final class EventServer: @unchecked Sendable {
    private struct Attachment {
        let transport: any RemoteEventTransportServer
        let listener: ExternalListener
    }

    private let bus: EventBus
    private let lock = NSLock()
    private var attachments: [ObjectIdentifier: Attachment] = [:]

    public init(bus: EventBus) {
        self.bus = bus
    }

    public func attach(_ transport: any RemoteEventTransportServer) {
        let listener: ExternalListener = Self.onMainSync {
            let listener = ExternalListener(destination: transport, kinds: [])
            bus.addPublishOnlyListener(listener, kinds: [])
            return listener
        }

        transport.setPublishHandler { [bus] event in
            bus.publish(event)
        }
        transport.setSubscribeHandler { [bus] kinds in
            Self.onMainSync {
                listener.kinds = kinds
                bus.setListenerKinds(listener, kinds: kinds)
            }
        }
        transport.setAskHandler { [bus] event in
            try await bus.ask(event)
        }
        transport.setCloseHandler { [weak self, weak transport] in
            guard let self, let transport else { return }
            self.detach(transport)
        }

        lock.withLock {
            attachments[ObjectIdentifier(transport)] = Attachment(
                transport: transport,
                listener: listener
            )
        }
    }

    public func detach(_ transport: any RemoteEventTransportServer) {
        let attachment = lock.withLock {
            attachments.removeValue(forKey: ObjectIdentifier(transport))
        }

        guard let attachment else { return }

        transport.setPublishHandler(nil)
        transport.setSubscribeHandler(nil)
        transport.setAskHandler(nil)
        transport.setCloseHandler(nil)
        Self.onMainSync {
            bus.removeListener(attachment.listener)
        }
        attachment.transport.close()
    }

    public func stop() {
        let transports = lock.withLock {
            attachments.values.map(\.transport)
        }

        for transport in transports {
            detach(transport)
        }
    }

    private static func onMainSync<T: Sendable>(_ body: @MainActor () -> T) -> T {
        if Thread.isMainThread {
            return MainActor.assumeIsolated(body)
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated(body)
        }
    }
}
