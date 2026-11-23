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
            (event: Event.getWorkspaces(GetWorkspacesEvent()), kind: EventKind.getWorkspaces),
            (event: Event.workspacesFetched(WorkspacesFetchedEvent(workspaces: [])), kind: EventKind.workspacesFetched),
            (
                event: Event.availableWorkspaces(AvailableWorkspacesEvent(workspaces: [])),
                kind: EventKind.availableWorkspaces
            ),
            (
                event: Event.createWorkspace(
                    CreateWorkspaceEvent(name: "placeholder", symbol: "book", applications: [])
                ),
                kind: EventKind.createWorkspace
            ),
            (
                event: Event.updateWorkspace(
                    UpdateWorkspaceEvent(
                        workspace: Workspace(name: "placeholder", symbol: "book")
                    )
                ),
                kind: EventKind.updateWorkspace
            ),
            (event: Event.deleteWorkspace(DeleteWorkspaceEvent(workspaceID: UUID())), kind: EventKind.deleteWorkspace),
            (
                event: Event.archiveWorkspace(ArchiveWorkspaceEvent(workspaceID: UUID())),
                kind: EventKind.archiveWorkspace
            ),
            (
                event: Event.unarchiveWorkspace(UnarchiveWorkspaceEvent(workspaceID: UUID())),
                kind: EventKind.unarchiveWorkspace
            ),
            (
                event: Event.switchWorkspace(SwitchWorkspaceEvent(workspaceID: UUID())),
                kind: EventKind.switchWorkspace
            ),
            (
                event: Event.stopWorkspace(StopWorkspaceEvent(workspaceID: UUID())),
                kind: EventKind.stopWorkspace
            ),
            (
                event: Event.workspaceMutationAcknowledged(.success(workspaceID: UUID())),
                kind: EventKind.workspaceMutationAcknowledged
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
            (
                event: Event.getComponentIdentity(GetComponentIdentityEvent()),
                kind: EventKind.getComponentIdentity
            ),
            (
                event:
                    Event
                    .componentIdentity(
                        ComponentIdentityEvent(identity: ComponentIdentity(identifier: "", version: "", build: ""))
                    ),
                kind: EventKind.componentIdentity
            ),
            (
                event: Event.prepareForApplicationUpdate(PrepareForApplicationUpdateEvent()),
                kind: EventKind.prepareForApplicationUpdate
            ),
            (
                event:
                    Event
                    .applicationUpdatePreparationAcknowledged(
                        ApplicationUpdatePrepAcknowledgement.ready(
                            identity: ComponentIdentity(identifier: "", version: "", build: "")
                        )
                    ),
                kind: EventKind.applicationUpdatePreparationAcknowledged
            ),
            (
                event:
                    Event.cancelApplicationUpdatePreparation(
                        CancelApplicationUpdatePreparationEvent()
                    ),
                kind: EventKind.cancelApplicationUpdatePreparation
            ),
            (
                event:
                    Event.applicationUpdatePreparationCancelled(
                        ApplicationUpdatePrepCancelledEvent(
                            identity: ComponentIdentity(
                                identifier: "",
                                version: "",
                                build: ""
                            )
                        )
                    ),
                kind: EventKind.applicationUpdatePreparationCancelled
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
            .getWorkspaces(GetWorkspacesEvent()),
            .workspacesFetched(WorkspacesFetchedEvent(workspaces: [])),
            .createWorkspace(CreateWorkspaceEvent(name: "placeholder", symbol: "book", applications: [])),
            .updateWorkspace(UpdateWorkspaceEvent(workspace: Workspace(name: "placeholder", symbol: "book"))),
            .deleteWorkspace(DeleteWorkspaceEvent(workspaceID: UUID())),
            .archiveWorkspace(ArchiveWorkspaceEvent(workspaceID: UUID())),
            .unarchiveWorkspace(UnarchiveWorkspaceEvent(workspaceID: UUID())),
            .switchWorkspace(SwitchWorkspaceEvent(workspaceID: UUID())),
            .stopWorkspace(StopWorkspaceEvent(workspaceID: UUID())),
            .workspaceMutationAcknowledged(WorkspaceMutationAcknowledgement.success(workspaceID: UUID())),
            .workspaceMutationAcknowledged(WorkspaceMutationAcknowledgement.failure(failure: .emptyWorkspaceName)),
            .workspaceMutationAcknowledged(
                WorkspaceMutationAcknowledgement.failure(failure: .workspaceNotFound(UUID()))
            ),
            .workspaceMutationAcknowledged(
                WorkspaceMutationAcknowledgement.failure(failure: .workspaceNotActive(UUID()))
            ),
            .availableWorkspaces(
                AvailableWorkspacesEvent(
                    workspaces: [
                        Workspace(name: "Placeholder", symbol: "book"),
                        Workspace(name: "Old", symbol: "archivebox", isArchived: true),
                    ],
                    activity: WorkspaceActivityState(
                        activeSession: .init(
                            workspaceID: UUID(),
                            startedAt: Date(timeIntervalSince1970: 100)
                        )
                    )
                )
            ),
            .workspaceMutationAcknowledged(WorkspaceMutationAcknowledgement.failure(failure: .updateInProgress)),
            .getAccessibilityStatus(GetAccessibilityStatusEvent()),
            .promptAccessibilityTrust(PromptAccessibilityTrustEvent()),
            .accessibilityStatus(AccessibilityStatusEvent(isTrusted: false)),
            .getSettings(GetSettingsEvent()),
            .settingsFetched(SettingsFetchedEvent(settings: Settings())),
            .availableSettings(AvailableSettingsEvent(settings: Settings())),
            .settingsMutationAcknowledgement(SettingsMutationAcknowledgement.success),
            .settingsMutationAcknowledgement(.failure(failure: .updateInProgress)),
            .updateSettings(UpdateSettingsEvent(settings: Settings())),
            .applySettings(ApplySettingsEvent()),
            .getComponentIdentity(GetComponentIdentityEvent()),
            .componentIdentity(
                ComponentIdentityEvent(identity: ComponentIdentity(identifier: "", version: "", build: ""))
            ),
            .prepareForApplicationUpdate(PrepareForApplicationUpdateEvent()),
            .applicationUpdatePreparationAcknowledged(
                ApplicationUpdatePrepAcknowledgement.failure(failure: .unexpected)
            ),
            .applicationUpdatePreparationAcknowledged(
                ApplicationUpdatePrepAcknowledgement.failure(failure: .workspaceShutdownFailed)
            ),
            .applicationUpdatePreparationAcknowledged(
                ApplicationUpdatePrepAcknowledgement
                    .ready(identity: ComponentIdentity(identifier: "", version: "", build: ""))
            ),
            .cancelApplicationUpdatePreparation(
                CancelApplicationUpdatePreparationEvent()
            ),
            .applicationUpdatePreparationCancelled(
                ApplicationUpdatePrepCancelledEvent(
                    identity: ComponentIdentity(
                        identifier: "",
                        version: "",
                        build: ""
                    )
                )
            ),
        ]
    )
    func roundTripsThroughJSON(_ event: Event) throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(event)
        let decoded = try decoder.decode(Event.self, from: data)
        #expect(decoded == event)
    }

    @Test("Workspace snapshots decode activity from older payloads as empty")
    func workspaceSnapshotsDecodeOlderPayloads() throws {
        let data = Data(#"{"workspaces":[]}"#.utf8)
        let decoder = JSONDecoder()

        let available = try decoder.decode(AvailableWorkspacesEvent.self, from: data)
        let fetched = try decoder.decode(WorkspacesFetchedEvent.self, from: data)

        #expect(available.activity == .empty)
        #expect(fetched.activity == .empty)
    }
}
