# Host

dawnAgent is the production host. It owns one `EventBus`, registers local listeners, and accepts remote clients through `EventServer`.

The bus is not a singleton. Tests create their own.

## Local bus

```swift
import libdawn

@MainActor
final class LayoutEngine: Listener {
    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?) {
        switch event {
        case .debugPing:
            reply?(.debugPong(DebugPongEvent(message: "ok")))
        case .switchSpace(let payload):
            // apply layout
            _ = payload.spaceIndex
        default:
            break
        }
    }
}

let bus = EventBus()
let layout = LayoutEngine()
bus.addListener(layout, kinds: [.switchSpace, .debugPing])
// omit kinds (or pass nil) to receive every kind
```

`Listener` is `@MainActor`. `handle` runs there. Registrations are weak: the bus does not keep your object alive. Keep your own strong reference.

`kinds: nil` (the default) means every kind. A non-empty set filters. An empty set means none.

```swift
bus.publish(.switchSpace(SwitchSpaceEvent(spaceIndex: 1)))

let reply = try await bus.ask(.debugPing(DebugPingEvent()))
// EventAskError.noHandler — no local listener for that kind
// EventAskError.timeout   — a listener was called but did not reply in time
```

`ask` only considers local listeners. A connected remote process does not count. If nobody on the host can reply, you get `noHandler` immediately, not a timeout.

Call `reply` at most once. The first reply wins if several listeners handle the same ask. The reply is the return value of `ask`; it is not published on the bus.

`removeListener(_:)` drops that object. `stop()` on the event server is separate (connections).

## Accepting remotes

```swift
let eventServer = EventServer(bus: bus)
let acceptor = XPCRemoteEventTransportAcceptor(eventServer: eventServer)
acceptor.start()
```
Each protocol implementation has its own Acceptor, responsible for hosting the service and accepting the connections, running `EventServer.attach` to register a successfull connection.

For XPC, each accepted XPC connection becomes a server-side transport attached to the bus. Remote `publish` is republished locally (and fanned out, including back to that client). Remote `ask` is `bus.ask`. Remote subscriptions update which kinds that client receives.

```swift
acceptor.stop()
eventServer.stop()
```

`acceptor.stop()` invalidates the listener and detaches connections. `eventServer.stop()` detaches anything still attached.

You can `attach` / `detach` any `RemoteEventTransportServer` (XPC from the acceptor, or `LoopbackEventLink.server` in tests). You should not construct any `RemoteEventTransportServer` yourself, unless you are implementing a new protocol.

## Exposing the Mach service

> Note: This is specific to XPC and the dawnAgent implementation

dawnAgent listens with `NSXPCListener(machServiceName:)`. dawnApp connects with the same name. Do not archive `NSXPCListenerEndpoint` (it can only travel through an `NSXPCCoder` on a live XPC connection).

Release builds are signed with Developer ID team `2Q5VC69BFD`. Both `DAWN.app` and the embedded agent have the app group `2Q5VC69BFD.app.opendawn`. macOS authorizes that group from the team prefix in the signature, so the agent can listen after DAWN opens it. No provisioning profile is required.

```swift
let eventServer = EventServer(bus: bus)
let acceptor = XPCRemoteEventTransportAcceptor(
    eventServer: eventServer,
    machServiceName: "2Q5VC69BFD.app.opendawn.eventbus"
)
acceptor.start()
```

Debug builds keep the service name `app.opendawn.dawnAgent`. Xcode does not sign those builds with the Developer ID team, so the team app group would not be honored. Run the `dawnApp` and `dawnAgent` schemes separately.

After `start()`, post an empty `DistributedNotificationCenter` ping so clients reconnect when dawnAgent comes up or restarts. Do not put the endpoint in the notification.

- Release Mach service: `2Q5VC69BFD.app.opendawn.eventbus`
- Debug Mach service: `app.opendawn.dawnAgent`
- Ready ping: `app.opendawn.dawnAgent.eventBusReady` (nil object, nil userInfo)

The login item still only controls launch at login. It does not choose the Mach service name.

`acceptor.endpoint` is still available for in-process tests that use an anonymous listener (`machServiceName: nil`). Production dawnAgent does not share that endpoint.

Client reconnect (subscribe to the ping, connect with `XPCRemoteEventTransportClient(machServiceName:)`, retry on XPC invalidation) is not part of this host.

## Tests without a real transport

Testing can use the `LoopbackEventLink` class. It is a pair of local client and server implementations. 

```swift
let hostBus = EventBus()
let eventServer = EventServer(bus: hostBus)
let link = LoopbackEventLink()
eventServer.attach(link.server)

let remote = RemoteEventBus(transport: link.client)
remote.addListener(myListener)
try await remote.ask(.debugPing(DebugPingEvent()))
```
