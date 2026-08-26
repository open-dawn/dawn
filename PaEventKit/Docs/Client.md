# Client

Clients never talk to `PaEventBus` directly. They use `PaRemoteEventBus` with a transport that points at the host.

## Connect

> Note: This is the XPC connection procedure. Protocols differ.

You need the host’s `NSXPCListenerEndpoint`.

Discovery is app glue: read the ticket the host wrote in the app group, then:

```swift
import PaEventKit

let endpoint: NSXPCListenerEndpoint = /* unarchive from app group */
let transport = XPCRemoteEventTransportClient(endpoint: endpoint)
let remote = PaRemoteEventBus(transport: transport)

remote.isConnected  // false after the connection invalidates
remote.disconnect()
```

On launch, the ticket may already exist. Subscribe to the host’s distributed notification (empty payload), reconnect when it fires, and reconnect when XPC invalidates.

This rendezvous is implemented by the host and client. The client API is the `PaRemoteEventBus`.

## Listen

```swift
@MainActor
final class MyClientListener: Listener {
    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
        // reply is always nil on the client. Host asks never reach remotes.
        if case .switchSpace(let payload) = event {
            // do something with it
            _ = payload.spaceIndex
        }
    }
}

let myListener = MyClientListener()
remote.addListener(myListener) // all kinds
remote.addListener(myListener, kinds: [.switchSpace])
remote.removeListener(store)
```

Registrations are weak. Kind filter: `nil` means all, a set is a union across this process’s listeners, empty set means none. The host is told that union over `subscribe`; it does not see each client listener object.

Client listeners only receive **publish** fan-out from the host. **They are not ask handlers.**

## Publish and ask

```swift
remote.publish(.switchSpace(PaSwitchSpaceEvent(spaceIndex: 3)))

let pong = try await remote.ask(
    .debugPing(PaDebugPingEvent()),
    timeout: .seconds(5)
)
```

`publish` is sent to the host bus and fanned out to matching listeners, including this client.

`ask` waits for one reply from a **local host** listener. Your client's `Listener` is not called. A one-shot tool (`pacli status`) can `ask` with zero listeners.

Errors:

- `PaEventRemoteError.notConnected` — the transport is down
- `PaEventAskError.noHandler` — the host has no local listener for that kind
- `PaEventAskError.timeout` — a host listener did not reply in time
- `PaEventRemoteError.invalidPayload` — the host reply could not be decoded

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
