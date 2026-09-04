# API

Public surface of PaEventKit. Import `PaEventKit`. Currently macOS 26+.

Internal types (`ExternalListener`, `AskSession`, `PaEventCodec`, XPC `@objc` protocols, `XPCRemoteEventTransportServer`) are not part of this API.

## Events

Closed enums. Payloads are structs in the kit.

```swift
public enum PaEventKind: String, Codable, Sendable, Hashable, CaseIterable {
    case debugPing, debugPong, switchSpace
}

public enum PaEvent: Codable, Sendable, Equatable {
    case debugPing(PaDebugPingEvent)
    case debugPong(PaDebugPongEvent)
    case switchSpace(PaSwitchSpaceEvent)

    public var kind: PaEventKind { get }
}
```

| Case | Payload | Notes |
|------|---------|--------|
| `debugPing` | `PaDebugPingEvent()` | Smoke `ask` |
| `debugPong` | `PaDebugPongEvent(message:)` | Default message `"pong"` |
| `switchSpace` | `PaSwitchSpaceEvent(spaceIndex:)` | |
| `initializedEvent` | `PaInitializedEvent()` | |

### How to Create an Event
To create an event: 
1. Create a payload file under `Features/Event/Events/<Domain>/`
2. Add new `PaEvent` case
3. Add new `PaEventKind` case. 

Do not define payloads in any other target, as that will cause sync issues.

## Listener

```swift
@MainActor
public protocol Listener: AnyObject {
    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?)
}
```

Inbox only. Does not publish. `reply` is non-`nil` only for `ask` calls on host listeners. Call `reply` at most once. On a remote bus listener, `reply` is always `nil`.

## PaEventBus

In-process dispatcher. Host API.

```swift
public final class PaEventBus: @unchecked Sendable {
    public init()

    public func addListener(_ listener: Listener, kinds: Set<PaEventKind>? = nil)
    public func removeListener(_ listener: Listener)
    public func publish(_ event: PaEvent)
    public func ask(_ event: PaEvent, timeout: Duration = .seconds(5)) async throws -> PaEvent
}
```

- Weak listener registry.
- `kinds == nil` → all; empty set → none.
- `publish` delivers to every matching listener, including remotes attached via `PaEventServer`.
- `ask` delivers only to matching **host** listeners. Throws `PaEventAskError.noHandler` or `.timeout`.

## PaRemoteEventBus

Mirror for a bus in another process. Same verbs as `PaEventBus`.

```swift
public final class PaRemoteEventBus: @unchecked Sendable {
    public init(transport: any RemoteEventTransportClient)

    public var isConnected: Bool { get }
    public func disconnect()

    public func addListener(_ listener: Listener, kinds: Set<PaEventKind>? = nil)
    public func removeListener(_ listener: Listener)
    public func publish(_ event: PaEvent)
    public func ask(_ event: PaEvent, timeout: Duration = .seconds(5)) async throws -> PaEvent
}
```

The remote bus does not import XPC or any transport by default.
The client must inject a transport, usually `XPCRemoteEventTransportClient`.
It is also possible to implement a new transport protocol, see below.

`addListener` / `removeListener` union this process’s kinds and `subscribe` on the transport. `ask` requires `isConnected`.

## PaEventServer

Wires server-side transports onto a `PaEventBus`. Transport-agnostic: an acceptor (or test) produces transports and calls `attach`.

```swift
public final class PaEventServer: @unchecked Sendable {
    public init(bus: PaEventBus)
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
    func setDeliveryHandler(_ handler: @escaping @Sendable (PaEvent) -> Void)
    func publish(_ event: PaEvent)
    func subscribe(kinds: Set<PaEventKind>?)
    func ask(_ event: PaEvent) async throws -> PaEvent
    func close()
}
```

`PaRemoteEventBus` is the usual caller. Incoming host fan-out arrives through `setDeliveryHandler`. `subscribe(kinds: nil)` means all; empty set means none.

#### Currently available transports
* **XPC:** `XPCRemoteEventTransportClient(machServiceName:)` for PaWM; `XPCRemoteEventTransportClient(endpoint:)` for anonymous in-process tests.
* **Loopback:** (used for testing) `LoopbackEventLink().client`.

### Server

Due to protocol differences, the protocol implementetion itself is responsible for accepting the connections. 
Meaning, the protocol needs to implement an Acceptor class that "hosts" the server, and when a connection is successfull, it needs to call `PaEventServer.attach` to register the client.

```swift
public protocol EventDelivering: AnyObject, Sendable {
    func deliver(_ event: PaEvent)
}

public protocol RemoteEventTransportServer: EventDelivering {
    func close()
    func setPublishHandler(_ handler: (@Sendable (PaEvent) -> Void)?)
    func setSubscribeHandler(_ handler: (@Sendable (Set<PaEventKind>?) -> Void)?)
    func setAskHandler(_ handler: (@Sendable (PaEvent) async throws -> PaEvent)?)
    func setCloseHandler(_ handler: (@Sendable () -> Void)?)
}
```

`deliver` is host → client. Incoming client verbs are the handlers. `PaEventServer.attach` installs those handlers.

**XPC:** `XPCRemoteEventTransportAcceptor(eventServer:)` accepts anonymous connections for tests. Pass `machServiceName:` for a login-item Mach service (PaWM). DO NOT instantiate the Server.

```swift
public final class XPCRemoteEventTransportAcceptor: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    public init(eventServer: PaEventServer, machServiceName: String? = nil)
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
public enum PaEventAskError: Error, Equatable, Sendable {
    case noHandler
    case timeout
}

public enum PaEventRemoteError: Error, Equatable, Sendable {
    case notConnected
    case invalidPayload
}
```

`PaEventAskError` is thrown by both buses. `PaEventRemoteError` is transport-side (disconnected client, bad XPC payload).
