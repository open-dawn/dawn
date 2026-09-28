# Host

PaWM is the production host. It owns one `PaEventBus`, registers local listeners, and accepts remote clients through `PaEventServer`.

The bus is not a singleton. Tests create their own.

## Local bus

```swift
import PaEventKit

@MainActor
final class LayoutEngine: Listener {
    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        switch event {
        case .debugPing:
            reply?(.debugPong(PaDebugPongEvent(message: "ok")))
        case .switchSpace(let payload):
            // apply layout
            _ = payload.spaceIndex
        default:
            break
        }
    }
}

let bus = PaEventBus()
let layout = LayoutEngine()
bus.addListener(layout, kinds: [.switchSpace, .debugPing])
// omit kinds (or pass nil) to receive every kind
```

`Listener` is `@MainActor`. `handle` runs there. Registrations are weak: the bus does not keep your object alive. Keep your own strong reference.

`kinds: nil` (the default) means every kind. A non-empty set filters. An empty set means none.

```swift
bus.publish(.switchSpace(PaSwitchSpaceEvent(spaceIndex: 1)))

let reply = try await bus.ask(.debugPing(PaDebugPingEvent()))
// PaEventAskError.noHandler — no local listener for that kind
// PaEventAskError.timeout   — a listener was called but did not reply in time
```

`ask` only considers local listeners. A connected remote process does not count. If nobody on the host can reply, you get `noHandler` immediately, not a timeout.

Call `reply` at most once. The first reply wins if several listeners handle the same ask. The reply is the return value of `ask`; it is not published on the bus.

`removeListener(_:)` drops that object. `stop()` on the event server is separate (connections).

## Accepting remotes

```swift
let eventServer = PaEventServer(bus: bus)
let acceptor = XPCRemoteEventTransportAcceptor(eventServer: eventServer)
acceptor.start()
```
Each protocol implementation has its own Acceptor, responsible for hosting the service and accepting the connections, running `PaEventServer.attach` to register a successfull connection.

For XPC, each accepted XPC connection becomes a server-side transport attached to the bus. Remote `publish` is republished locally (and fanned out, including back to that client). Remote `ask` is `bus.ask`. Remote subscriptions update which kinds that client receives.

```swift
acceptor.stop()
eventServer.stop()
```

`acceptor.stop()` invalidates the listener and detaches connections. `eventServer.stop()` detaches anything still attached.

You can `attach` / `detach` any `RemoteEventTransportServer` (XPC from the acceptor, or `LoopbackEventLink.server` in tests). You should not construct any `RemoteEventTransportServer` yourself, unless you are implementing a new protocol.

## Exposing the Mach service

> Note: This is specific to XPC and the PaWM implementation

PaWM is a login item. Launchd advertises a Mach service named as the helper’s bundle identifier. That name is how clients connect; do not archive `NSXPCListenerEndpoint` (it can only travel through an `NSXPCCoder` on a live XPC connection).

```swift
let eventServer = PaEventServer(bus: bus)
let acceptor = XPCRemoteEventTransportAcceptor(
    eventServer: eventServer,
    machServiceName: "app.opendawn.PaWM"
)
acceptor.start()
```

After `start()`, post an empty `DistributedNotificationCenter` ping so clients reconnect when PaWM comes up or restarts. Do not put the endpoint in the notification.

- Mach service name: `app.opendawn.PaWM` (the login item bundle ID)
- Ready ping: `app.opendawn.PaWM.eventBusReady` (nil object, nil userInfo)

`acceptor.endpoint` is still available for in-process tests that use an anonymous listener (`machServiceName: nil`). Production PaWM does not share that endpoint.

Client reconnect (subscribe to the ping, connect with `XPCRemoteEventTransportClient(machServiceName:)`, retry on XPC invalidation) is not part of this host.

## Tests without a real transport

Testing can use the `LoopbackEventLink` class. It is a pair of local client and server implementations. 

```swift
let hostBus = PaEventBus()
let eventServer = PaEventServer(bus: hostBus)
let link = LoopbackEventLink()
eventServer.attach(link.server)

let remote = PaRemoteEventBus(transport: link.client)
remote.addListener(myListener)
try await remote.ask(.debugPing(PaDebugPingEvent()))
```
