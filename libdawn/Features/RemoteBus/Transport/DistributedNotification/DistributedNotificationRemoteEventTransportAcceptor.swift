import Foundation

public final class DistributedRemoteEventTransportAcceptor: @unchecked Sendable {
    private let eventServer: EventServer
    private let serviceName: String
    private let notificationCenter: DistributedNotificationCenter
    private let lock = NSLock()
    private var observer: NSObjectProtocol?
    private var transports: [String: DistributedRemoteEventTransportServer] = [:]

    public init(
        eventServer: EventServer,
        serviceName: String,
        notificationCenter: DistributedNotificationCenter = .default()
    ) {
        self.eventServer = eventServer
        self.serviceName = serviceName
        self.notificationCenter = notificationCenter
    }

    public func start() {
        lock.withLock {
            guard observer == nil else { return }
            observer = notificationCenter.addObserver(
                forName: DistributedNotificationMessage.requestName(serviceName: serviceName),
                object: nil,
                queue: nil
            ) { [weak self] notification in
                self?.handle(notification)
            }
        }
    }

    public func stop() {
        let snapshot = lock.withLock {
            () -> (NSObjectProtocol?, [DistributedRemoteEventTransportServer]) in
            let snapshot = (observer, Array(transports.values))
            observer = nil
            transports.removeAll()
            return snapshot
        }

        if let observer = snapshot.0 {
            notificationCenter.removeObserver(observer)
        }
        snapshot.1.forEach(eventServer.detach)
    }

    private func handle(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let clientID = userInfo[DistributedNotificationMessage.clientIDKey] as? String,
              let rawOperation = userInfo[DistributedNotificationMessage.operationKey] as? String,
              let operation = DistributedNotificationMessage.Operation(rawValue: rawOperation)
        else { return }

        if operation == .handshake {
            handleHandshake(clientID: clientID, userInfo: userInfo)
            return
        }

        guard let transport = lock.withLock({ transports[clientID] }) else { return }

        switch operation {
        case .publish:
            guard let payload = userInfo[DistributedNotificationMessage.payloadKey] as? Data else { return }
            transport.handlePublish(payload: payload)

        case .subscribe:
            let kindNames = userInfo[DistributedNotificationMessage.kindsKey] as? [String] ?? []
            let includeAll = userInfo[DistributedNotificationMessage.includeAllKey] as? Bool ?? false
            transport.handleSubscribe(kindNames: kindNames, includeAll: includeAll)

        case .ask:
            guard let requestID = userInfo[DistributedNotificationMessage.requestIDKey] as? String,
                  let payload = userInfo[DistributedNotificationMessage.payloadKey] as? Data
            else { return }
            transport.handleAsk(requestID: requestID, payload: payload)

        case .close:
            removeTransport(clientID: clientID)

        case .handshake, .handshakeResponse, .askResponse, .deliver, .disconnect:
            return
        }
    }

    private func handleHandshake(clientID: String, userInfo: [AnyHashable: Any]) {
        guard let requestID = userInfo[DistributedNotificationMessage.requestIDKey] as? String else {
            return
        }

        let result = lock.withLock { () -> (DistributedRemoteEventTransportServer, Bool) in
            if let transport = transports[clientID] {
                return (transport, false)
            }
            let transport = DistributedRemoteEventTransportServer(
                serviceName: serviceName,
                clientID: clientID,
                notificationCenter: notificationCenter
            )
            transports[clientID] = transport
            return (transport, true)
        }
        if result.1 {
            eventServer.attach(result.0)
        }

        notificationCenter.postNotificationName(
            DistributedNotificationMessage.responseName(
                serviceName: serviceName,
                clientID: clientID
            ),
            object: nil,
            userInfo: [
                DistributedNotificationMessage.operationKey:
                    DistributedNotificationMessage.Operation.handshakeResponse.rawValue,
                DistributedNotificationMessage.requestIDKey: requestID,
                DistributedNotificationMessage.successKey: true
            ],
            deliverImmediately: true
        )
    }

    private func removeTransport(clientID: String) {
        let transport = lock.withLock { transports.removeValue(forKey: clientID) }
        if let transport {
            eventServer.detach(transport)
        }
    }

    deinit {
        if let observer {
            notificationCenter.removeObserver(observer)
        }
    }
}
