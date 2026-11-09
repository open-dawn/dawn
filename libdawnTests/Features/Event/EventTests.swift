import Foundation
@testable import libdawn
import Testing

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
            (event: Event.archiveContext(ArchiveContextEvent(contextID: UUID())), kind: EventKind.archiveContext),
            (
                event: Event.unarchiveContext(UnarchiveContextEvent(contextID: UUID())),
                kind: EventKind.unarchiveContext
            ),
            (
                event: Event.switchContext(SwitchContextEvent(contextID: UUID())),
                kind: EventKind.switchContext
            ),
            (
                event: Event.stopContext(StopContextEvent(contextID: UUID())),
                kind: EventKind.stopContext
            ),
            (
                event: Event.contextMutationAcknowledged(.success(contextID: UUID())),
                kind: EventKind.contextMutationAcknowledged
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
            (
                event: Event.getSettings(GetSettingsEvent()),
                kind: EventKind.getSettings
            ),
            (
                event: Event.settingsFetched(SettingsFetchedEvent(settings: Settings())),
                kind: EventKind.settingsFetched
            ),
            (
                event: Event.availableSettings(AvailableSettingsEvent(settings: Settings())),
                kind: EventKind.availableSettings
            ),
            (
                event: Event.settingsMutationAcknowledgement(SettingsMutationAcknowledgement.success),
                kind: EventKind.settingsMutationAcknowledgement
            ),
            (
                event: Event.updateSettings(UpdateSettingsEvent(settings: Settings())),
                kind: EventKind.updateSettings
            ),
            (
                event: Event.applySettings(ApplySettingsEvent()),
                kind: EventKind.applySettings
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
            .archiveContext(ArchiveContextEvent(contextID: UUID())),
            .unarchiveContext(UnarchiveContextEvent(contextID: UUID())),
            .switchContext(SwitchContextEvent(contextID: UUID())),
            .stopContext(StopContextEvent(contextID: UUID())),
            .contextMutationAcknowledged(ContextMutationAcknowledgement.success(contextID: UUID())),
            .contextMutationAcknowledged(ContextMutationAcknowledgement.failure(failure: .emptyContextName)),
            .contextMutationAcknowledged(ContextMutationAcknowledgement.failure(failure: .contextNotFound(UUID()))),
            .contextMutationAcknowledged(ContextMutationAcknowledgement.failure(failure: .contextNotActive(UUID()))),
            .availableContexts(
                AvailableContextsEvent(
                    contexts: [
                        WorkspaceContext(name: "Placeholder", symbol: "book"),
                        WorkspaceContext(name: "Old", symbol: "archivebox", isArchived: true)
                    ],
                    activity: WorkspaceActivityState(
                        activeSession: .init(
                            contextID: UUID(),
                            startedAt: Date(timeIntervalSince1970: 100)
                        )
                    )
                )
            ),
            .getAccessibilityStatus(GetAccessibilityStatusEvent()),
            .promptAccessibilityTrust(PromptAccessibilityTrustEvent()),
            .accessibilityStatus(AccessibilityStatusEvent(isTrusted: false)),
            .getSettings(GetSettingsEvent()),
            .settingsFetched(SettingsFetchedEvent(settings: Settings())),
            .availableSettings(AvailableSettingsEvent(settings: Settings())),
            .settingsMutationAcknowledgement(SettingsMutationAcknowledgement.success),
            .updateSettings(UpdateSettingsEvent(settings: Settings())),
            .applySettings(ApplySettingsEvent()),
        ]
    )
    func roundTripsThroughJSON(_ event: Event) throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(event)
        let decoded = try decoder.decode(Event.self, from: data)
        #expect(decoded == event)
    }

    @Test("Context snapshots decode activity from older payloads as empty")
    func contextSnapshotsDecodeOlderPayloads() throws {
        let data = Data(#"{"contexts":[]}"#.utf8)
        let decoder = JSONDecoder()

        let available = try decoder.decode(AvailableContextsEvent.self, from: data)
        let fetched = try decoder.decode(ContextsFetchedEvent.self, from: data)

        #expect(available.activity == .empty)
        #expect(fetched.activity == .empty)
    }
}
