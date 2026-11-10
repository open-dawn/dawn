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
}
