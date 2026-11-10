import Foundation
import libdawn
import Testing

@Suite("ContextClient")
struct ContextClientTests {
    private let focusID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private let oldID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    private var focus: WorkspaceContext {
        WorkspaceContext(
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

    private var archived: WorkspaceContext {
        WorkspaceContext(
            id: oldID,
            name: "Old",
            symbol: "moon",
            isArchived: true
        )
    }

    @Test("list prints every context")
    func listPrintsContexts() async throws {
        let text = try await ContextClient.list(archivedOnly: false, json: false) { event in
            #expect(event == .getContexts(GetContextsEvent()))
            return .contextsFetched(ContextsFetchedEvent(contexts: [focus, archived]))
        }

        #expect(text == """
        NAME   SYMBOL  ID                                    APPS  STATE
        Focus  star    AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE  1     live
        Old    moon    11111111-2222-3333-4444-555555555555  0     archived
        """)
    }

    @Test("list can show only archived contexts")
    func listFiltersArchived() async throws {
        let text = try await ContextClient.list(archivedOnly: true, json: false) { _ in
            .contextsFetched(ContextsFetchedEvent(contexts: [focus, archived]))
        }

        #expect(text.contains("Old"))
        #expect(!text.contains("Focus"))
    }

    @Test("list prints JSON")
    func listPrintsJSON() async throws {
        let context = focus
        let text = try await ContextClient.list(archivedOnly: false, json: true) { _ in
            .availableContexts(AvailableContextsEvent(contexts: [context]))
        }
        let decoded = try JSONDecoder().decode([WorkspaceContext].self, from: Data(text.utf8))

        #expect(decoded == [context])
    }

    @Test("list reports an empty catalog")
    func listIsEmpty() async throws {
        let text = try await ContextClient.list(archivedOnly: false, json: false) { _ in
            .contextsFetched(ContextsFetchedEvent(contexts: []))
        }

        #expect(text == "No contexts.")
    }

    @Test("show prints one context")
    func showPrintsContext() async throws {
        let text = try await ContextClient.show(id: focusID, json: false) { _ in
            .contextsFetched(ContextsFetchedEvent(contexts: [focus, archived]))
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

    @Test("id commands report the acknowledged context", arguments: [
        "switched",
        "deleted",
        "archived",
        "unarchived"
    ])
    func mutationsReportTheContext(verb: String) async throws {
        let event = mutationEvent(verb: verb, id: focusID)
        let text = try await ContextClient.mutate(
            id: focusID,
            verb: verb,
            event: event,
            json: false
        ) { received in
            #expect(received == event)
            return .contextMutationAcknowledged(.success(contextID: focusID))
        }

        #expect(text == "\(verb) \(focusID.uuidString)")
    }

    @Test("a rejected mutation surfaces the agent failure")
    func mutationSurfacesFailure() async {
        await #expect(throws: ContextMutationAcknowledgement.Failure.contextArchived(focusID)) {
            try await ContextClient.mutate(
                id: focusID,
                verb: "switched",
                event: .switchContext(SwitchContextEvent(contextID: focusID)),
                json: false
            ) { _ in
                .contextMutationAcknowledged(
                    .failure(failure: .contextArchived(focusID))
                )
            }
        }
    }

    private func mutationEvent(verb: String, id: UUID) -> Event {
        switch verb {
        case "deleted": .deleteContext(DeleteContextEvent(contextID: id))
        case "archived": .archiveContext(ArchiveContextEvent(contextID: id))
        case "unarchived": .unarchiveContext(UnarchiveContextEvent(contextID: id))
        default: .switchContext(SwitchContextEvent(contextID: id))
        }
    }

    @Test("show fails when the id is missing")
    func showRequiresAKnownContext() async {
        await #expect(throws: CLIError.contextNotFound(focusID)) {
            try await ContextClient.show(id: focusID, json: false) { _ in
                .contextsFetched(ContextsFetchedEvent(contexts: []))
            }
        }
    }

    @Test("create sends the request and prints the new id")
    func createSendsTheRequest() async throws {
        let created = UUID(uuidString: "BBBBBBBB-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let request = CreateContextEvent(
            name: "Focus",
            symbol: "star",
            applications: ContextClient.applications(from: ["com.apple.Safari"]),
            transition: WorkspaceTransition(
                activationPolicy: .merge,
                terminalCommand: "echo hi"
            )
        )
        let text = try await ContextClient.create(request: request, json: false) { event in
            #expect(event == .createContext(request))
            return .contextMutationAcknowledged(.success(contextID: created))
        }

        #expect(text == "created \(created.uuidString)")
    }

    @Test("update sends the edited context")
    func updateSendsTheEditedContext() async throws {
        let text = try await ContextClient.update(
            id: focusID,
            edits: ContextEdits(
                name: "Deep",
                bundleIdentifiers: ["com.apple.mail"],
                activation: .close,
                clearsTerminalCommand: true
            ),
            replacement: nil,
            json: false
        ) { event in
            switch event {
            case .getContexts:
                var current = focus
                current.transition.terminalCommand = "echo hi"
                return .contextsFetched(ContextsFetchedEvent(contexts: [current]))
            case let .updateContext(payload):
                #expect(payload.context.name == "Deep")
                #expect(payload.context.symbol == "star")
                #expect(payload.context.applications.map(\.bundleIdentifier) == ["com.apple.mail"])
                #expect(payload.context.transition.activationPolicy == .close)
                #expect(payload.context.transition.terminalCommand == nil)
                return .contextMutationAcknowledged(.success(contextID: focusID))
            default:
                throw AgentError.unexpectedResponse(event.kind)
            }
        }

        #expect(text == "updated \(focusID.uuidString)")
    }

    @Test("update rejects a file whose id does not match")
    func updateRejectsMismatchedFile() async {
        await #expect(throws: CLIError.contextIdentifierMismatch(expected: focusID, received: oldID)) {
            try await ContextClient.update(
                id: focusID,
                edits: ContextEdits(),
                replacement: archived,
                json: false
            ) { _ in
                Issue.record("update should fail before asking")
                return .debugPong(DebugPongEvent())
            }
        }
    }
}
