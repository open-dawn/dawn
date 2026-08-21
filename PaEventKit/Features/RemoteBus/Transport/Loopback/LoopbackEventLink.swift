public final class LoopbackEventLink: @unchecked Sendable {
    public let client: LoopbackRemoteEventTransportClient
    public let server: LoopbackRemoteEventTransportServer

    public init() {
        let client = LoopbackRemoteEventTransportClient()
        let server = LoopbackRemoteEventTransportServer()
        client.server = server
        server.client = client
        self.client = client
        self.server = server
    }
}
