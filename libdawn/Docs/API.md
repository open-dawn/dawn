# API

Public surface of libdawn. Import `libdawn`. Currently macOS 26+.

Internal types (`ExternalListener`, `AskSession`, `EventCodec`, XPC `@objc` protocols, `XPCRemoteEventTransportServer`) are not part of this API.

## Events

Closed enums. Payloads are structs in the kit.

```swift
public enum EventKind: String, Codable, Sendable, Hashable, CaseIterable {
    case debugPing, debugPong, switchSpace
}

public enum Event: Codable, Sendable, Equatable {
    case debugPing(DebugPingEvent)
    case debugPong(DebugPongEvent)
    case switchSpace(SwitchSpaceEvent)

    public var kind: EventKind { get }
}
```

| Case | Payload | Notes |
|------|---------|--------|
| `debugPing` | `DebugPingEvent()` | Smoke `ask` |
| `debugPong` | `DebugPongEvent(message:)` | Default message `"pong"` |
| `switchSpace` | `SwitchSpaceEvent(spaceIndex:)` | |
| `initializedEvent` | `InitializedEvent()` | |

### How to Create an Event
To create an event: 
1. Create a payload file under `Features/Event/Events/<Domain>/`
2. Add new `Event` case
3. Add new `EventKind` case. 

Do not define payloads in any other target, as that will cause sync issues.

## Listener

```swift
@MainActor
public protocol Listener: AnyObject {
    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?)
}
```

Inbox only. Does not publish. `reply` is non-`nil` only for `ask` calls on host listeners. Call `reply` at most once. On a remote bus listener, `reply` is always `nil`.

## EventBus

In-process dispatcher. Host API.

```swift
public final class EventBus: @unchecked Sendable {
    public init()

    public func addListener(_ listener: Listener, kinds: Set<EventKind>? = nil)
    public func removeListener(_ listener: Listener)
    public func publish(_ event: Event)
    public func ask(_ event: Event, timeout: Duration = .seconds(5)) async throws -> Event
}
```

- Weak listener registry.
- `kinds == nil` → all; empty set → none.
- `publish` delivers to every matching listener, including remotes attached via `EventServer`.
- `ask` delivers only to matching **host** listeners. Throws `EventAskError.noHandler` or `.timeout`.

## RemoteEventBus

Mirror for a bus in another process. Same verbs as `EventBus`.

```swift
public enum RemoteConnectionState: Sendable, Equatable {
    case disconnected, connecting, connected
}

public final class RemoteEventBus: @unchecked Sendable {
    public init(transport: any RemoteEventTransportClient)

    public var isConnected: Bool { get }
    public var connectionState: RemoteConnectionState { get }
    public func disconnect()
    public func attemptReconnect() async throws

    public func setConnectionStateHandler(
        _ handler: (@Sendable (RemoteConnectionState) -> Void)?
    )
    public func addListener(_ listener: Listener, kinds: Set<EventKind>? = nil)
    public func removeListener(_ listener: Listener)
    public func publish(_ event: Event)
    public func ask(_ event: Event, timeout: Duration = .seconds(5)) async throws -> Event
}
```

The remote bus does not import XPC or any transport by default.
The client must inject a transport, usually `XPCRemoteEventTransportClient`.
It is also possible to implement a new transport protocol, see below.

`addListener` / `removeListener` union this process’s kinds and `subscribe` on the transport. `ask` requires `isConnected`.

## EventServer

Wires server-side transports onto a `EventBus`. Transport-agnostic: an acceptor (or test) produces transports and calls `attach`.

```swift
public final class EventServer: @unchecked Sendable {
    public init(bus: EventBus)
    public func attach(_ transport: any RemoteEventTransportServer)
    public func detach(_ transport: any RemoteEventTransportServer)
    public func stop()
}
```

## Transports

### Client

```swift
public protocol RemoteEventTransportClient: AnyObject, Sendable {
    var isConnected: Bool { get }
    var connectionState: RemoteConnectionState { get }

    func setDeliveryHandler(_ handler: @escaping @Sendable (Event) -> Void)
    func setConnectionStateHandler(
        _ handler: (@Sendable (RemoteConnectionState) -> Void)?
    )
    func publish(_ event: Event)
    func subscribe(kinds: Set<EventKind>?)
    func ask(_ event: Event) async throws -> Event
    func attemptReconnect() async throws
    func close()
}
```

`RemoteEventBus` is the usual caller. Incoming host fan-out arrives through `setDeliveryHandler`. `subscribe(kinds: nil)` means all; empty set means none.

#### Currently available transports
* **XPC:** `XPCRemoteEventTransportClient(machServiceName:)` for dawnAgent; `XPCRemoteEventTransportClient(endpoint:)` for anonymous in-process tests.
* **Loopback:** (used for testing) `LoopbackEventLink().client`.

### Server

Due to protocol differences, the protocol implementetion itself is responsible for accepting the connections. 
Meaning, the protocol needs to implement an Acceptor class that "hosts" the server, and when a connection is successfull, it needs to call `EventServer.attach` to register the client.

```swift
public protocol EventDelivering: AnyObject, Sendable {
    func deliver(_ event: Event)
}

public protocol RemoteEventTransportServer: EventDelivering {
    func close()
    func setPublishHandler(_ handler: (@Sendable (Event) -> Void)?)
    func setSubscribeHandler(_ handler: (@Sendable (Set<EventKind>?) -> Void)?)
    func setAskHandler(_ handler: (@Sendable (Event) async throws -> Event)?)
    func setCloseHandler(_ handler: (@Sendable () -> Void)?)
}
```

`deliver` is host → client. Incoming client verbs are the handlers. `EventServer.attach` installs those handlers.

**XPC:** `XPCRemoteEventTransportAcceptor(eventServer:)` accepts anonymous connections for tests. Pass `machServiceName:` for a login-item Mach service (dawnAgent). DO NOT instantiate the Server.

```swift
public final class XPCRemoteEventTransportAcceptor: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    public init(eventServer: EventServer, machServiceName: String? = nil)
    public var endpoint: NSXPCListenerEndpoint? { get }
    public func start()
    public func stop()
}
```

`machServiceName: nil` (the default) uses `NSXPCListener.anonymous()`. A non-nil name uses `NSXPCListener(machServiceName:)`.

```swift
public final class XPCRemoteEventTransportClient: NSObject, RemoteEventTransportClient, @unchecked Sendable {
    public init(endpoint: NSXPCListenerEndpoint)
    public init(machServiceName: String, options: NSXPCConnection.Options = [])
}
```

**Loopback:** `LoopbackEventLink().server` passed to `attach`. In this case, the Link is the Acceptor because it creates a client/server pair locally.

```swift
public final class LoopbackEventLink: @unchecked Sendable {
    public let client: LoopbackRemoteEventTransportClient
    public let server: LoopbackRemoteEventTransportServer
    public init()
}
```

A custom protocol (for example WebSocket) implements the two transport protocols and is injected the same way.

## Errors

```swift
public enum EventAskError: Error, Equatable, Sendable {
    case noHandler
    case timeout
}

public enum EventRemoteError: Error, Equatable, Sendable {
    case notConnected
    case invalidPayload
}
```

`EventAskError` is thrown by both buses. `EventRemoteError` is transport-side (disconnected client, bad XPC payload).
