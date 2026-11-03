import Foundation
import Testing
import libdawn

@testable import dawnAgent

@MainActor
@Suite("ContextManager")
struct ContextManagerTests {
    @Test("Valid repository loads contexts")
    func validRepository() async {
        let mockRepository = MockSettingsRepository()
        let publisherSpy = SnapshotPublisherSpy()

        await #expect(throws: Never.self) {
            try await ContextManager(repository: mockRepository, snapshotPublisher: publisherSpy)
        }
    }

    @Test("Corrupted repository resets to empty")
    func corruptedRepository() async throws {
        let mockRepository = MockSettingsRepository(loadFailuresRemaining: 1)
        let publisherSpy = SnapshotPublisherSpy()
        let manager = try await ContextManager(repository: mockRepository, snapshotPublisher: publisherSpy)

        #expect(await manager.getAvailableContexts().isEmpty)
        #expect(await mockRepository.loadFailuresRemaining == 0)
    }

    @Test("Failed reset propagates error")
    func failedReset() async {
        let mockRepository = MockSettingsRepository(
            shouldFailSave: true,
            loadFailuresRemaining: 1
        )
        let publisherSpy = SnapshotPublisherSpy()

        await #expect(throws: SettingsRepositoryError.corruptedData(description: "save")) {
            try await ContextManager(repository: mockRepository, snapshotPublisher: publisherSpy)
        }
    }

    @Test("Returns contexts from store snapshot")
    func returnContexts() async throws {
        var document: SettingsDocument = .empty
        document.contexts = createMockWorkspaceContext(count: 3)
        let mockRepository = MockSettingsRepository(
            document: document
        )
        let publisherSpy = SnapshotPublisherSpy()

        let manager = try #require(
            try? await ContextManager(repository: mockRepository, snapshotPublisher: publisherSpy)
        )
        #expect(await manager.getAvailableContexts() == document.contexts)
    }

    @Test("Returns context when id exists")
    func validIdGetContext() async throws {
        var document: SettingsDocument = .empty
        document.contexts = createMockWorkspaceContext(count: 3)
        let mockRepository = MockSettingsRepository(
            document: document
        )
        let publisherSpy = SnapshotPublisherSpy()

        let manager = try #require(
            try? await ContextManager(repository: mockRepository, snapshotPublisher: publisherSpy)
        )
        let target = document.contexts[0]
        #expect(await manager.getContext(id: target.id) == target)
    }

    @Test("Returns nil when id is missing")
    func invalidIdGetContext() async throws {
        var document: SettingsDocument = .empty
        document.contexts = createMockWorkspaceContext(count: 3)
        let mockRepository = MockSettingsRepository(
            document: document
        )
        let publisherSpy = SnapshotPublisherSpy()

        let manager = try #require(
            try? await ContextManager(repository: mockRepository, snapshotPublisher: publisherSpy)
        )
        #expect(await manager.getContext(id: UUID()) == nil)
    }

    private func createMockWorkspaceContext(count: Int) -> [WorkspaceContext] {
        var res: [WorkspaceContext] = []
        for index in 1...count {
            res.append(WorkspaceContext(name: "placeholder: \(index)", symbol: "test", applications: []))
        }
        return res
    }

    @Test("Create publishes the created snapshot")
    func createPublishesTheCreatedSnapshot() async throws {
        let mockRepository = MockSettingsRepository()
        let publisherSpy = SnapshotPublisherSpy()

        let manager = try #require(
            try? await ContextManager(repository: mockRepository, snapshotPublisher: publisherSpy)
        )

        let createdContext = try await manager.createContext(name: "Placeholder", symbol: "book", applications: [])

        #expect(publisherSpy.publishedSnapshots == [[createdContext]])
    }

    @Test("Update publishes the updated snapshot")
    func updatePublishesTheUpdatedSnapshot() async throws {
        let publisherSpy = SnapshotPublisherSpy()

        var context = WorkspaceContext(name: "Placeholder", symbol: "book")

        var document: SettingsDocument = .empty
        document.contexts = [context]

        let mockRepository = MockSettingsRepository(document: document)

        let manager = try #require(
            try? await ContextManager(repository: mockRepository, snapshotPublisher: publisherSpy)
        )

        context.name = "Placeholder 2"

        try await manager.updateContext(context)

        #expect(publisherSpy.publishedSnapshots == [[context]])
    }

    @Test("Delete publishes the remaining contexts")
    func deletePublishesTheRemainingContexts() async throws {
        let deletedContext = WorkspaceContext(
            name: "Deleted",
            symbol: "trash"
        )
        let remainingContext = WorkspaceContext(
            name: "Placeholder",
            symbol: "book"
        )

        var document: SettingsDocument = .empty
        document.contexts = [deletedContext, remainingContext]

        let mockRepository = MockSettingsRepository(document: document)
        let publisherSpy = SnapshotPublisherSpy()

        let manager = try #require(
            try? await ContextManager(repository: mockRepository, snapshotPublisher: publisherSpy)
        )

        try await manager.deleteContext(id: deletedContext.id)

        #expect(publisherSpy.publishedSnapshots == [[remainingContext]])
    }

    @Test("Validation failure does not publish")
    func validationFailureDoesNotPublish() async throws {
        let repository = MockSettingsRepository()
        let publisher = SnapshotPublisherSpy()
        let manager = try await ContextManager(
            repository: repository,
            snapshotPublisher: publisher
        )

        await #expect(throws: SettingsStoreError.emptyContextName) {
            _ = try await manager.createContext(
                name: " ",
                symbol: "book",
                applications: []
            )
        }

        #expect(publisher.publishedSnapshots.isEmpty)
    }

    @Test("Persistence failure does not publish")
    func persistenceFailureDoesNotPublish() async throws {
        let repository = MockSettingsRepository()
        let publisher = SnapshotPublisherSpy()
        let manager = try await ContextManager(
            repository: repository,
            snapshotPublisher: publisher
        )

        await repository.setShouldFailSave(true)

        await #expect(
            throws: SettingsRepositoryError.corruptedData(
                description: "save"
            )
        ) {
            _ = try await manager.createContext(
                name: "Placeholder",
                symbol: "book",
                applications: []
            )
        }

        #expect(publisher.publishedSnapshots.isEmpty)
        #expect(await manager.getAvailableContexts().isEmpty)
    }

    @Test("Read operations do not publish")
    func readOperationsDoNotPublish() async throws {
        let context = WorkspaceContext(
            name: "Placeholder",
            symbol: "book",
            applications: []
        )

        var document: SettingsDocument = .empty
        document.contexts = [context]

        let repository = MockSettingsRepository(document: document)
        let publisher = SnapshotPublisherSpy()
        let manager = try await ContextManager(
            repository: repository,
            snapshotPublisher: publisher
        )

        _ = await manager.getAvailableContexts()
        _ = await manager.getContext(id: context.id)
        _ = await manager.getContext(id: UUID())

        #expect(publisher.publishedSnapshots.isEmpty)
    }

    @Test("Concurrent mutations publish monotonically newer snapshots")
    func concurrentMutationsPublishMonotonicSnapshots() async throws {
        let mutationCount = 100
        let repository = MockSettingsRepository()
        let publisher = SnapshotPublisherSpy()

        let manager = try await ContextManager(
            repository: repository,
            snapshotPublisher: publisher
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<mutationCount {
                group.addTask {
                    _ = try await manager.createContext(
                        name: "Context \(index)",
                        symbol: "circle",
                        applications: []
                    )
                }
            }

            try await group.waitForAll()
        }

        let snapshotSizes = publisher.publishedSnapshots.map(\.count)
        let publicationsAreMonotonic = zip(
            snapshotSizes,
            snapshotSizes.dropFirst()
        ).allSatisfy { pair in
            pair.0 <= pair.1
        }

        #expect(publisher.publishedSnapshots.count == mutationCount)
        #expect(publicationsAreMonotonic)
        #expect(snapshotSizes.last == mutationCount)
    }

    @Test("returns persisted workspace activity")
    func returnsWorkspaceActivity() async throws {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )
        let activeSince = Date(
            timeIntervalSince1970: 100
        )

        var document = SettingsDocument.empty
        document.contexts = [context]
        document.workspaceActivity.activate(
            contextID: context.id,
            at: activeSince
        )

        let repository = MockSettingsRepository(
            document: document
        )
        let manager = try await ContextManager(
            repository: repository,
            snapshotPublisher: SnapshotPublisherSpy()
        )

        let activity = await manager.getWorkspaceActivity()

        #expect(activity.activeContextID == context.id)
        #expect(activity.activeSince == activeSince)
    }

    @Test("recording activation returns and persists activity")
    func recordsWorkspaceActivity() async throws {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )
        let activatedAt = Date(
            timeIntervalSince1970: 100
        )

        var document = SettingsDocument.empty
        document.contexts = [context]

        let repository = MockSettingsRepository(
            document: document
        )
        let manager = try await ContextManager(
            repository: repository,
            snapshotPublisher: SnapshotPublisherSpy()
        )

        let activity = try await manager.recordContextActivation(
            contextID: context.id,
            at: activatedAt
        )

        #expect(activity.activeContextID == context.id)
        #expect(activity.activeSince == activatedAt)
        #expect(
            await repository.document?.workspaceActivity
                == activity
        )
    }

    @Test("stopping returns and persists inactive activity")
    func stopsWorkspaceActivity() async throws {
        let context = WorkspaceContext(
            name: "Work",
            symbol: "briefcase"
        )
        let stoppedAt = Date(
            timeIntervalSince1970: 200
        )

        var document = SettingsDocument.empty
        document.contexts = [context]
        document.workspaceActivity.activate(
            contextID: context.id,
            at: Date(timeIntervalSince1970: 100)
        )

        let repository = MockSettingsRepository(
            document: document
        )
        let manager = try await ContextManager(
            repository: repository,
            snapshotPublisher: SnapshotPublisherSpy()
        )

        let activity = try await manager.stopActiveContext(
            at: stoppedAt
        )

        #expect(activity.activeContextID == nil)
        #expect(
            activity.lastActiveAt(for: context.id)
                == stoppedAt
        )
        #expect(
            await repository.document?.workspaceActivity
                == activity
        )
    }

    @Test("Retrieval returns active and archived contexts in stored order")
    func retrievalKeepsStoredOrder() async throws {
        let study = WorkspaceContext(name: "Study", symbol: "book")
        let archived = WorkspaceContext(
            name: "Old",
            symbol: "archivebox",
            isArchived: true
        )
        let games = WorkspaceContext(name: "Games", symbol: "gamecontroller")

        var document: SettingsDocument = .empty
        document.contexts = [study, archived, games]

        let manager = try await ContextManager(
            repository: MockSettingsRepository(document: document),
            snapshotPublisher: SnapshotPublisherSpy()
        )

        #expect(await manager.getAvailableContexts() == [study, archived, games])
        #expect(await manager.getContext(id: archived.id) == archived)
    }

    @Test("Archive publishes the stored list with the flag set")
    func archivePublishesStoredList() async throws {
        let study = WorkspaceContext(name: "Study", symbol: "book")
        let games = WorkspaceContext(name: "Games", symbol: "gamecontroller")

        var document: SettingsDocument = .empty
        document.contexts = [study, games]

        let publisher = SnapshotPublisherSpy()
        let manager = try await ContextManager(
            repository: MockSettingsRepository(document: document),
            snapshotPublisher: publisher
        )

        try await manager.archiveContext(id: study.id)

        let archivedStudy = WorkspaceContext(
            id: study.id,
            name: study.name,
            symbol: study.symbol,
            isArchived: true
        )

        #expect(publisher.publishedSnapshots == [[archivedStudy, games]])
    }

    @Test("Unarchive publishes the stored list with the flag cleared")
    func unarchivePublishesStoredList() async throws {
        let study = WorkspaceContext(name: "Study", symbol: "book")
        let archived = WorkspaceContext(
            name: "Old",
            symbol: "archivebox",
            isArchived: true
        )

        var document: SettingsDocument = .empty
        document.contexts = [study, archived]

        let publisher = SnapshotPublisherSpy()
        let manager = try await ContextManager(
            repository: MockSettingsRepository(document: document),
            snapshotPublisher: publisher
        )

        try await manager.unarchiveContext(id: archived.id)

        let restored = WorkspaceContext(
            id: archived.id,
            name: archived.name,
            symbol: archived.symbol
        )

        #expect(publisher.publishedSnapshots == [[study, restored]])
    }

    @Test("Missing archive does not publish")
    func missingArchiveDoesNotPublish() async throws {
        let publisher = SnapshotPublisherSpy()
        let manager = try await ContextManager(
            repository: MockSettingsRepository(),
            snapshotPublisher: publisher
        )
        let missingID = UUID()

        await #expect(throws: SettingsStoreError.contextNotFound(missingID)) {
            try await manager.archiveContext(id: missingID)
        }

        #expect(publisher.publishedSnapshots.isEmpty)
    }
}

actor MockSettingsRepository: SettingsRepository {
    private(set) var shouldFailSave: Bool
    private(set) var loadFailuresRemaining: Int
    private(set) var document: SettingsDocument?

    init(
        shouldFailSave: Bool = false,
        loadFailuresRemaining: Int = 0,
        document: SettingsDocument? = nil
    ) {
        self.shouldFailSave = shouldFailSave
        self.loadFailuresRemaining = loadFailuresRemaining
        self.document = document
    }

    func setShouldFailSave(_ value: Bool) {
        shouldFailSave = value
    }

    func setLoadFailuresRemaining(_ value: Int) {
        loadFailuresRemaining = value
    }

    func setDocument(_ document: SettingsDocument?) {
        self.document = document
    }

    func load() async throws -> SettingsDocument? {
        if loadFailuresRemaining > 0 {
            loadFailuresRemaining -= 1
            throw SettingsRepositoryError.corruptedData(description: "load")
        }

        return document
    }

    func save(_ document: SettingsDocument) async throws {
        guard !shouldFailSave else {
            throw SettingsRepositoryError.corruptedData(description: "save")
        }

        self.document = document
    }
}

final class SnapshotPublisherSpy: ContextSnapshotPublishing {
    private(set) var publishedSnapshots: [[WorkspaceContext]] = []

    func publishAvailableContexts(_ contexts: [libdawn.WorkspaceContext]) {
        publishedSnapshots.append(contexts)
    }
}
