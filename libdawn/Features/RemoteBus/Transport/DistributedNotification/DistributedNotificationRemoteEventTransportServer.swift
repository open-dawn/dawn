import Foundation

final class DistributedRemoteEventTransportServer:
    RemoteEventTransportServer,
    @unchecked Sendable
{
    private let serviceName: String
    let clientID: String
    private let notificationCenter: DistributedNotificationCenter
    private let lock = NSLock()
    private var closed = false
    private var publishHandler: (@Sendable (Event) -> Void)?
    private var subscribeHandler: (@Sendable (Set<EventKind>?) -> Void)?
    private var askHandler: (@Sendable (Event) async throws -> Event)?
    private var closeHandler: (@Sendable () -> Void)?

    init(
        serviceName: String,
        clientID: String,
        notificationCenter: DistributedNotificationCenter
    ) {
        self.serviceName = serviceName
        self.clientID = clientID
        self.notificationCenter = notificationCenter
    }

    func deliver(_ event: Event) {
        guard let payload = try? EventCodec.encode(event) else { return }
        post(.deliver, payload: payload)
    }

    func close() {
        let shouldClose = lock.withLock { () -> Bool in
            guard !closed else { return false }
            closed = true
            return true
        }
        guard shouldClose else { return }
        post(.disconnect)
    }

    func setPublishHandler(_ handler: (@Sendable (Event) -> Void)?) {
        lock.withLock { publishHandler = handler }
    }

    func setSubscribeHandler(_ handler: (@Sendable (Set<EventKind>?) -> Void)?) {
        lock.withLock { subscribeHandler = handler }
    }

    func setAskHandler(_ handler: (@Sendable (Event) async throws -> Event)?) {
        lock.withLock { askHandler = handler }
    }

    func setCloseHandler(_ handler: (@Sendable () -> Void)?) {
        lock.withLock { closeHandler = handler }
    }

    func handlePublish(payload: Data) {
        guard let event = try? EventCodec.decode(payload) else { return }
        let handler = lock.withLock { publishHandler }
        handler?(event)
    }

    func handleSubscribe(kindNames: [String], includeAll: Bool) {
        let handler = lock.withLock { subscribeHandler }
        if includeAll {
            handler?(nil)
        } else {
            handler?(Set(kindNames.compactMap(EventKind.init(rawValue:))))
        }
    }

    func handleAsk(requestID: String, payload: Data) {
        let handler = lock.withLock { askHandler }
        Task { [weak self] in
            guard let self else { return }
            guard let handler else {
                post(
                    .askResponse,
                    requestID: requestID,
                    success: false,
                    failure: .notConnected
                )
                return
            }

            do {
                let event = try EventCodec.decode(payload)
                let response = try await handler(event)
                let responsePayload = try EventCodec.encode(response)
                post(
                    .askResponse,
                    requestID: requestID,
                    payload: responsePayload,
                    success: true
                )
            } catch {
                post(
                    .askResponse,
                    requestID: requestID,
                    success: false,
                    failure: DistributedNotificationMessage.Failure(error: error)
                )
            }
        }
    }

    private func post(
        _ operation: DistributedNotificationMessage.Operation,
        requestID: String? = nil,
        payload: Data? = nil,
        success: Bool? = nil,
        failure: DistributedNotificationMessage.Failure? = nil
    ) {
        var userInfo: [String: Any] = [
            DistributedNotificationMessage.operationKey: operation.rawValue
        ]
        userInfo[DistributedNotificationMessage.requestIDKey] = requestID
        userInfo[DistributedNotificationMessage.payloadKey] = payload
        userInfo[DistributedNotificationMessage.successKey] = success
        userInfo[DistributedNotificationMessage.failureKey] = failure?.rawValue

        notificationCenter.postNotificationName(
            DistributedNotificationMessage.responseName(
                serviceName: serviceName,
                clientID: clientID
            ),
            object: nil,
            userInfo: userInfo,
            deliverImmediately: true
        )
    }
}
