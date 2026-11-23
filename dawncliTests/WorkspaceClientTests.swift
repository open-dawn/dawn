import Foundation
import libdawn
import Testing

@Suite("WorkspaceClient")
struct WorkspaceClientTests {
    private let focusID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private let oldID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    private var focus: Workspace {
        Workspace(
            id: focusID,
            name: "Focus",
            symbol: "star",
            applications: [
                WorkspaceApplication(
                    bundleIdentifier: "com.apple.Safari",
                    displayName: "Safari"
                )
            ]
        )
    }

    private var archived: Workspace {
        Workspace(
            id: oldID,
            name: "Old",
            symbol: "moon",
            isArchived: true
        )
    }

    @Test("list prints every workspace")
    func listPrintsWorkspaces() async throws {
        let text = try await WorkspaceClient.list(archivedOnly: false, json: false) { event in
            #expect(event == .getWorkspaces(GetWorkspacesEvent()))
            return .workspacesFetched(WorkspacesFetchedEvent(workspaces: [focus, archived]))
        }

        #expect(text == """
        NAME   SYMBOL  ID                                    APPS  STATE
        Focus  star    AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE  1     live
        Old    moon    11111111-2222-3333-4444-555555555555  0     archived
        """)
    }

    @Test("list can show only archived workspaces")
    func listFiltersArchived() async throws {
        let text = try await WorkspaceClient.list(archivedOnly: true, json: false) { _ in
            .workspacesFetched(WorkspacesFetchedEvent(workspaces: [focus, archived]))
        }

        #expect(text.contains("Old"))
        #expect(!text.contains("Focus"))
    }

    @Test("list prints JSON")
    func listPrintsJSON() async throws {
        let workspace = focus
        let text = try await WorkspaceClient.list(archivedOnly: false, json: true) { _ in
            .availableWorkspaces(AvailableWorkspacesEvent(workspaces: [workspace]))
        }
        let decoded = try JSONDecoder().decode([Workspace].self, from: Data(text.utf8))

        #expect(decoded == [workspace])
    }

    @Test("list reports an empty catalog")
    func listIsEmpty() async throws {
        let text = try await WorkspaceClient.list(archivedOnly: false, json: false) { _ in
            .workspacesFetched(WorkspacesFetchedEvent(workspaces: []))
        }

        #expect(text == "No workspaces.")
    }

    @Test("show prints one workspace")
    func showPrintsWorkspace() async throws {
        let text = try await WorkspaceClient.show(id: focusID, json: false) { _ in
            .workspacesFetched(WorkspacesFetchedEvent(workspaces: [focus, archived]))
        }

        #expect(text == """
        Focus (star)
          id: AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE
          archived: no
          activation: hide
          terminal command: none
          apps:
          Safari (com.apple.Safari)
        """)
    }

    @Test("id commands report the acknowledged workspace", arguments: [
        "switched",
        "deleted",
        "archived",
        "unarchived"
    ])
    func mutationsReportTheWorkspace(verb: String) async throws {
        let event = mutationEvent(verb: verb, id: focusID)
        let text = try await WorkspaceClient.mutate(
            id: focusID,
            verb: verb,
            event: event,
            json: false
        ) { received in
            #expect(received == event)
            return .workspaceMutationAcknowledged(.success(workspaceID: focusID))
        }

        #expect(text == "\(verb) \(focusID.uuidString)")
    }

    @Test("a rejected mutation surfaces the agent failure")
    func mutationSurfacesFailure() async {
        await #expect(throws: WorkspaceMutationAcknowledgement.Failure.workspaceArchived(focusID)) {
            try await WorkspaceClient.mutate(
                id: focusID,
                verb: "switched",
                event: .switchWorkspace(SwitchWorkspaceEvent(workspaceID: focusID)),
                json: false
            ) { _ in
                .workspaceMutationAcknowledged(
                    .failure(failure: .workspaceArchived(focusID))
                )
            }
        }
    }

    private func mutationEvent(verb: String, id: UUID) -> Event {
        switch verb {
        case "deleted": .deleteWorkspace(DeleteWorkspaceEvent(workspaceID: id))
        case "archived": .archiveWorkspace(ArchiveWorkspaceEvent(workspaceID: id))
        case "unarchived": .unarchiveWorkspace(UnarchiveWorkspaceEvent(workspaceID: id))
        default: .switchWorkspace(SwitchWorkspaceEvent(workspaceID: id))
        }
    }

    @Test("show fails when the id is missing")
    func showRequiresAKnownWorkspace() async {
        await #expect(throws: CLIError.workspaceNotFound(focusID)) {
            try await WorkspaceClient.show(id: focusID, json: false) { _ in
                .workspacesFetched(WorkspacesFetchedEvent(workspaces: []))
            }
        }
    }

    @Test("create sends the request and prints the new id")
    func createSendsTheRequest() async throws {
        let created = UUID(uuidString: "BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let safariURL = URL(filePath: "/Applications/Safari.app")
        let request = CreateWorkspaceEvent(
            name: "Focus",
            symbol: "star",
            applications: try WorkspaceClient.applications(
                from: ["com.apple.Safari"],
                urlForApplication: { _ in safariURL }
            ),
            transition: WorkspaceTransition(
                activationPolicy: .merge,
                terminalCommand: "echo hi"
            )
        )
        let text = try await WorkspaceClient.create(request: request, json: false) { event in
            #expect(event == .createWorkspace(request))
            return .workspaceMutationAcknowledged(.success(workspaceID: created))
        }

        #expect(text == "created \(created.uuidString)")
    }

    @Test("applications resolves the bundle name and URL")
    func applicationsResolvesInstalledApp() throws {
        let appURL = URL(filePath: "/System/Applications/Calculator.app")
        let resolved = try WorkspaceClient.applications(
            from: ["com.apple.calculator"],
            urlForApplication: { bundleIdentifier in
                bundleIdentifier == "com.apple.calculator" ? appURL : nil
            }
        )

        #expect(resolved.count == 1)
        #expect(resolved[0].bundleIdentifier == "com.apple.calculator")
        #expect(resolved[0].displayName == "Calculator")
        #expect(resolved[0].applicationURL == appURL)
    }

    @Test("applications fails when the bundle identifier is not installed")
    func applicationsRejectsUnknownApp() {
        #expect(throws: CLIError.applicationNotFound("com.example.missing")) {
            try WorkspaceClient.applications(
                from: ["com.example.missing"],
                urlForApplication: { _ in nil }
            )
        }
    }

    @Test("update sends the edited workspace")
    func updateSendsTheEditedWorkspace() async throws {
        let mailURL = URL(filePath: "/System/Applications/Mail.app")
        let text = try await WorkspaceClient.update(
            id: focusID,
            edits: WorkspaceEdits(
                name: "Deep",
                bundleIdentifiers: ["com.apple.mail"],
                activation: .close,
                clearsTerminalCommand: true
            ),
            replacement: nil,
            json: false,
            urlForApplication: { bundleIdentifier in
                bundleIdentifier == "com.apple.mail" ? mailURL : nil
            },
            ask: { event in
                switch event {
                case .getWorkspaces:
                    var current = focus
                    current.transition.terminalCommand = "echo hi"
                    return .workspacesFetched(WorkspacesFetchedEvent(workspaces: [current]))
                case let .updateWorkspace(payload):
                    #expect(payload.workspace.name == "Deep")
                    #expect(payload.workspace.symbol == "star")
                    #expect(payload.workspace.applications.map(\.bundleIdentifier) == ["com.apple.mail"])
                    #expect(payload.workspace.applications.map(\.applicationURL) == [mailURL])
                    #expect(payload.workspace.transition.activationPolicy == .close)
                    #expect(payload.workspace.transition.terminalCommand == nil)
                    return .workspaceMutationAcknowledged(.success(workspaceID: focusID))
                default:
                    throw AgentError.unexpectedResponse(event.kind)
                }
            }
        )

        #expect(text == "updated \(focusID.uuidString)")
    }

    @Test("update can clear the application list")
    func updateClearsApplications() async throws {
        let text = try await WorkspaceClient.update(
            id: focusID,
            edits: WorkspaceEdits(clearsApplications: true),
            replacement: nil,
            json: false
        ) { event in
            switch event {
            case .getWorkspaces:
                return .workspacesFetched(WorkspacesFetchedEvent(workspaces: [focus]))
            case let .updateWorkspace(payload):
                #expect(payload.workspace.applications.isEmpty)
                return .workspaceMutationAcknowledged(.success(workspaceID: focusID))
            default:
                throw AgentError.unexpectedResponse(event.kind)
            }
        }

        #expect(text == "updated \(focusID.uuidString)")
    }

    @Test("update rejects a file whose id does not match")
    func updateRejectsMismatchedFile() async {
        await #expect(throws: CLIError.workspaceIdentifierMismatch(expected: focusID, received: oldID)) {
            try await WorkspaceClient.update(
                id: focusID,
                edits: WorkspaceEdits(),
                replacement: archived,
                json: false
            ) { _ in
                Issue.record("update should fail before asking")
                return .debugPong(DebugPongEvent())
            }
        }
    }
}
