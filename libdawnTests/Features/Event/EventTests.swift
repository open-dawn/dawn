import Foundation
import Testing

@testable import libdawn

@Suite("Event")
struct EventTests {
    @Test(
        "kind matches each event case",
        arguments: [
            (event: Event.debugPing(DebugPingEvent()), kind: EventKind.debugPing),
            (event: Event.debugPong(DebugPongEvent()), kind: EventKind.debugPong),
            (event: Event.initialized(InitializedEvent()), kind: EventKind.initialized),
            (event: Event.getContexts(GetContextsEvent()), kind: EventKind.getContexts),
            (event: Event.contextsFetched(ContextsFetchedEvent(contexts: [])), kind: EventKind.contextsFetched),
            (
                event: Event.availableContexts(AvailableContextsEvent(contexts: [])),
                kind: EventKind.availableContexts
            ),
            (
                event: Event.createContext(
                    CreateContextEvent(name: "placeholder", symbol: "book", applications: [])
                ),
                kind: EventKind.createContext
            ),
            (
                event: Event.updateContext(
                    UpdateContextEvent(
                        context: WorkspaceContext(name: "placeholder", symbol: "book")
                    )
                ),
                kind: EventKind.updateContext
            ),
            (event: Event.deleteContext(DeleteContextEvent(contextID: UUID())), kind: EventKind.deleteContext),
            (
                event: Event.switchContext(SwitchContextEvent(contextID: UUID())),
                kind: EventKind.switchContext
            ),
            (
                event: Event.contextMutationAcknowledged(.success(contextID: UUID())),
                kind: EventKind.contextMutationAcknowledged
            ),
            (event: Event.getMenuBarVisibility(GetMenuBarVisibilityEvent()), kind: .getMenuBarVisibility),
            (
                event: Event.setMenuBarVisibility(SetMenuBarVisibilityEvent(isVisible: false)),
                kind: .setMenuBarVisibility
            ),
            (
                event: Event.menuBarVisibilityState(
                    MenuBarVisibilityStateEvent(
                        isVisible: true
                    )
                ),
                kind: .menuBarVisibilityState
            ),
            (
                event: Event.menuBarVisibilityMutationAcknowledged(
                    .success(isVisible: false)
                ),
                kind: .menuBarVisibilityMutationAcknowledged
            ),
            (
                event: Event.getAccessibilityStatus(GetAccessibilityStatusEvent()),
                kind: EventKind.getAccessibilityStatus
            ),
            (
                event: Event.promptAccessibilityTrust(PromptAccessibilityTrustEvent()),
                kind: EventKind.promptAccessibilityTrust
            ),
            (
                event: Event.accessibilityStatus(AccessibilityStatusEvent(isTrusted: true)),
                kind: EventKind.accessibilityStatus
            ),
        ]
    )
    func exposesKind(_ eventWithKind: (event: Event, kind: EventKind)) {
        #expect(eventWithKind.event.kind == eventWithKind.kind)
    }

    @Test(
        "Codable round-trips all cases",
        arguments: [
            Event.debugPing(DebugPingEvent()),
            .debugPong(DebugPongEvent(message: "hello")),
            .initialized(InitializedEvent()),
            .getContexts(GetContextsEvent()),
            .contextsFetched(ContextsFetchedEvent(contexts: [])),
            .createContext(CreateContextEvent(name: "placeholder", symbol: "book", applications: [])),
            .updateContext(UpdateContextEvent(context: WorkspaceContext(name: "placeholder", symbol: "book"))),
            .deleteContext(DeleteContextEvent(contextID: UUID())),
            .switchContext(SwitchContextEvent(contextID: UUID())),
            .contextMutationAcknowledged(ContextMutationAcknowledgement.success(contextID: UUID())),
            .contextMutationAcknowledged(ContextMutationAcknowledgement.failure(failure: .emptyContextName)),
            .contextMutationAcknowledged(ContextMutationAcknowledgement.failure(failure: .contextNotFound(UUID()))),
            .availableContexts(
                AvailableContextsEvent(contexts: [WorkspaceContext(name: "Placeholder", symbol: "book")])
            ),
            .getMenuBarVisibility(GetMenuBarVisibilityEvent()),
            .setMenuBarVisibility(SetMenuBarVisibilityEvent(isVisible: false)),
            .menuBarVisibilityState(MenuBarVisibilityStateEvent(isVisible: true)),
            .menuBarVisibilityMutationAcknowledged(.success(isVisible: false)),
            .menuBarVisibilityMutationAcknowledged(.failure(.persistence)),
            .menuBarVisibilityMutationAcknowledged(.failure(.unexpected)),
            .getAccessibilityStatus(GetAccessibilityStatusEvent()),
            .promptAccessibilityTrust(PromptAccessibilityTrustEvent()),
            .accessibilityStatus(AccessibilityStatusEvent(isTrusted: false)),
        ]
    )
    func roundTripsThroughJSON(_ event: Event) throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(event)
        let decoded = try decoder.decode(Event.self, from: data)
        #expect(decoded == event)
    }
}
