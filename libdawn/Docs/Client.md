# Client

Clients never talk to `EventBus` directly. They use `RemoteEventBus` with a transport that points at the host.

## Connect

> Note: This is the XPC connection procedure. Protocols differ.

dawnAgent advertises a Mach service named as its bundle ID. Connect with that name:

```swift
import libdawn

let transport = XPCRemoteEventTransportClient(
    machServiceName: "app.opendawn.dawnAgent"
)
let remote = RemoteEventBus(transport: transport)

remote.isConnected  // true only after a transport handshake with the host
remote.disconnect()
```

On launch, subscribe to the host’s empty distributed notification (`app.opendawn.dawnAgent.eventBusReady`). Keep one `RemoteEventBus` and call `attemptReconnect()` when the ping fires, and once when a live connection drops. Do not retry in a loop after a failed handshake; wait for the next ready ping.

`publish` is best-effort. Use `ask` when you need confirmation from a host listener.

In-process tests can still use `XPCRemoteEventTransportClient(endpoint:)` with an anonymous listener.

This rendezvous is implemented by the host and client. The client API is the `RemoteEventBus`.

## Listen

```swift
@MainActor
final class MyClientListener: Listener {
    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?) {
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
remote.publish(.switchSpace(SwitchSpaceEvent(spaceIndex: 3)))

let pong = try await remote.ask(
    .debugPing(DebugPingEvent()),
    timeout: .seconds(5)
)
```

`publish` is sent to the host bus and fanned out to matching listeners, including this client.

`ask` waits for one reply from a **local host** listener. Your client's `Listener` is not called. A one-shot tool (`dawncli status`) can `ask` with zero listeners.

Errors:

- `EventRemoteError.notConnected` — the transport is down
- `EventAskError.noHandler` — the host has no local listener for that kind
- `EventAskError.timeout` — a host listener did not reply in time
- `EventRemoteError.invalidPayload` — the host reply could not be decoded

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
