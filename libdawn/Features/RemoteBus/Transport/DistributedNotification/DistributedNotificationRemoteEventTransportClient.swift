import Foundation

public final class DistributedRemoteEventTransportClient:
    RemoteEventTransportClient,
    @unchecked Sendable
{
    private let serviceName: String
    private let clientID = UUID().uuidString
    private let notificationCenter: DistributedNotificationCenter
    private let lock = NSLock()
    private var observer: NSObjectProtocol?
    private var deliveryHandler: (@Sendable (Event) -> Void)?
    private var connectionStateHandler: (@Sendable (RemoteConnectionState) -> Void)?
    private var handshakeSessions: [String: DistributedHandshakeSession] = [:]
    private var askSessions: [String: DistributedAskSession] = [:]
    private var state: RemoteConnectionState = .disconnected
    private var stopped = false

    public init(
        serviceName: String,
        notificationCenter: DistributedNotificationCenter = .default()
    ) {
        self.serviceName = serviceName
        self.notificationCenter = notificationCenter
        observer = notificationCenter.addObserver(
            forName: DistributedNotificationMessage.responseName(
                serviceName: serviceName,
                clientID: clientID
            ),
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handle(notification)
        }
    }

    public var isConnected: Bool {
        lock.withLock { state == .connected }
    }

    public var connectionState: RemoteConnectionState {
        lock.withLock { state }
    }

    public func setDeliveryHandler(_ handler: @escaping @Sendable (Event) -> Void) {
        lock.withLock {
            deliveryHandler = handler
        }
    }

    public func setConnectionStateHandler(
        _ handler: (@Sendable (RemoteConnectionState) -> Void)?
    ) {
        lock.withLock {
            connectionStateHandler = handler
        }
    }

    public func publish(_ event: Event) {
        guard isConnected, let payload = try? EventCodec.encode(event) else { return }
        post(.publish, payload: payload)
    }

    public func subscribe(kinds: Set<EventKind>?) {
        guard isConnected else { return }

        var userInfo = baseUserInfo(operation: .subscribe)
        if let kinds {
            userInfo[DistributedNotificationMessage.kindsKey] = kinds.map(\.rawValue)
            userInfo[DistributedNotificationMessage.includeAllKey] = false
        } else {
            userInfo[DistributedNotificationMessage.kindsKey] = [String]()
            userInfo[DistributedNotificationMessage.includeAllKey] = true
        }
        post(userInfo)
    }

    public func ask(_ event: Event) async throws -> Event {
        guard isConnected else {
            throw EventRemoteError.notConnected
        }

        let payload = try EventCodec.encode(event)
        let requestID = UUID().uuidString

        return try await withCheckedThrowingContinuation { continuation in
            let session = DistributedAskSession(continuation: continuation)
            let stored = lock.withLock { () -> Bool in
                guard !stopped, state == .connected else { return false }
                askSessions[requestID] = session
                return true
            }

            guard stored else {
                session.complete(.failure(EventRemoteError.notConnected))
                return
            }

            post(.ask, requestID: requestID, payload: payload)
        }
    }

    public func attemptReconnect() async throws {
        let requestID = UUID().uuidString
        let canAttempt = lock.withLock { () -> Bool in
            guard !stopped else { return false }
            state = .connecting
            return true
        }

        guard canAttempt else {
            throw EventRemoteError.notConnected
        }
        notifyConnectionState(.connecting)

        let connected = await withCheckedContinuation { continuation in
            let session = DistributedHandshakeSession(continuation: continuation)
            lock.withLock {
                handshakeSessions[requestID] = session
            }
            post(.handshake, requestID: requestID)

            Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                self?.finishHandshake(requestID: requestID, connected: false)
            }
        }

        guard connected else {
            setConnectionState(.disconnected)
            throw EventRemoteError.notConnected
        }

        let committed = lock.withLock { () -> Bool in
            guard !stopped else { return false }
            state = .connected
            return true
        }
        guard committed else {
            throw EventRemoteError.notConnected
        }
        notifyConnectionState(.connected)
    }

    public func close() {
        let snapshot = lock.withLock { () -> CloseSnapshot? in
            guard !stopped else { return nil }
            stopped = true
            state = .disconnected

            let snapshot = CloseSnapshot(
                observer: observer,
                handshakes: Array(handshakeSessions.values),
                asks: Array(askSessions.values)
            )
            observer = nil
            handshakeSessions.removeAll()
            askSessions.removeAll()
            deliveryHandler = nil
            connectionStateHandler = nil
            return snapshot
        }

        guard let snapshot else { return }
        post(.close)
        if let observer = snapshot.observer {
            notificationCenter.removeObserver(observer)
        }
        snapshot.handshakes.forEach { $0.complete(false) }
        snapshot.asks.forEach { $0.complete(.failure(EventRemoteError.notConnected)) }
    }

    private func handle(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rawOperation = userInfo[DistributedNotificationMessage.operationKey] as? String,
              let operation = DistributedNotificationMessage.Operation(rawValue: rawOperation)
        else { return }

        switch operation {
        case .handshakeResponse:
            guard let requestID = userInfo[DistributedNotificationMessage.requestIDKey] as? String else {
                return
            }
            let success = userInfo[DistributedNotificationMessage.successKey] as? Bool ?? false
            finishHandshake(requestID: requestID, connected: success)

        case .askResponse:
            handleAskResponse(userInfo)

        case .deliver:
            guard let payload = userInfo[DistributedNotificationMessage.payloadKey] as? Data,
                  let event = try? EventCodec.decode(payload)
            else { return }
            let handler = lock.withLock { deliveryHandler }
            handler?(event)

        case .disconnect:
            failPendingRequests()
            setConnectionState(.disconnected)

        case .handshake, .publish, .subscribe, .ask, .close:
            return
        }
    }

    private func handleAskResponse(_ userInfo: [AnyHashable: Any]) {
        guard let requestID = userInfo[DistributedNotificationMessage.requestIDKey] as? String else {
            return
        }
        let session = lock.withLock { askSessions.removeValue(forKey: requestID) }
        guard let session else { return }

        let success = userInfo[DistributedNotificationMessage.successKey] as? Bool ?? false
        guard success,
              let payload = userInfo[DistributedNotificationMessage.payloadKey] as? Data
        else {
            let rawFailure = userInfo[DistributedNotificationMessage.failureKey] as? String
            let failure = rawFailure.flatMap(DistributedNotificationMessage.Failure.init(rawValue:))
            session.complete(.failure((failure ?? .unknown).error))
            return
        }

        do {
            session.complete(.success(try EventCodec.decode(payload)))
        } catch {
            session.complete(.failure(error))
        }
    }

    private func finishHandshake(requestID: String, connected: Bool) {
        let session = lock.withLock { handshakeSessions.removeValue(forKey: requestID) }
        session?.complete(connected)
    }

    private func failPendingRequests() {
        let sessions = lock.withLock { () -> [DistributedAskSession] in
            let sessions = Array(askSessions.values)
            askSessions.removeAll()
            return sessions
        }
        sessions.forEach { $0.complete(.failure(EventRemoteError.notConnected)) }
    }

    private func setConnectionState(_ newState: RemoteConnectionState) {
        let shouldNotify = lock.withLock { () -> Bool in
            guard !stopped, state != newState else { return false }
            state = newState
            return true
        }
        guard shouldNotify else { return }
        notifyConnectionState(newState)
    }

    private func notifyConnectionState(_ state: RemoteConnectionState) {
        let handler = lock.withLock { connectionStateHandler }
        handler?(state)
    }

    private func post(
        _ operation: DistributedNotificationMessage.Operation,
        requestID: String? = nil,
        payload: Data? = nil
    ) {
        var userInfo = baseUserInfo(operation: operation)
        userInfo[DistributedNotificationMessage.requestIDKey] = requestID
        userInfo[DistributedNotificationMessage.payloadKey] = payload
        post(userInfo)
    }

    private func baseUserInfo(
        operation: DistributedNotificationMessage.Operation
    ) -> [String: Any] {
        [
            DistributedNotificationMessage.clientIDKey: clientID,
            DistributedNotificationMessage.operationKey: operation.rawValue
        ]
    }

    private func post(_ userInfo: [String: Any]) {
        notificationCenter.postNotificationName(
            DistributedNotificationMessage.requestName(serviceName: serviceName),
            object: nil,
            userInfo: userInfo,
            deliverImmediately: true
        )
    }

    deinit {
        if let observer {
            notificationCenter.removeObserver(observer)
        }
    }
}

private final class DistributedHandshakeSession: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Bool, Never>?

    init(continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func complete(_ connected: Bool) {
        let continuation = lock.withLock { () -> CheckedContinuation<Bool, Never>? in
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(returning: connected)
    }
}

private struct CloseSnapshot {
    let observer: NSObjectProtocol?
    let handshakes: [DistributedHandshakeSession]
    let asks: [DistributedAskSession]
}

private final class DistributedAskSession: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Event, Error>?

    init(continuation: CheckedContinuation<Event, Error>) {
        self.continuation = continuation
    }

    func complete(_ result: Result<Event, Error>) {
        let continuation = lock.withLock { () -> CheckedContinuation<Event, Error>? in
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(with: result)
    }
}
