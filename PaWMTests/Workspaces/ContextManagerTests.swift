import Foundation
import PaEventKit
import Testing

@testable import PaWM

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

    func publishAvailableContexts(_ contexts: [PaEventKit.WorkspaceContext]) {
        publishedSnapshots.append(contexts)
    }
}
