import Foundation
import Testing
import libdawn

@testable import dawnAgent

@MainActor
@Suite("WorkspaceCatalog")
struct WorkspaceCatalogTests {
    @Test("Valid repository loads workspaces")
    func validRepository() async {
        let mockRepository = MockSettingsRepository()

        await #expect(throws: Never.self) {
            _ = try await SettingsStore.make(repository: mockRepository)
        }
    }

    @Test("Corrupted repository resets to empty")
    func corruptedRepository() async throws {
        let mockRepository = MockSettingsRepository(loadFailuresRemaining: 1)
        let store = try await SettingsStore.make(repository: mockRepository)

        #expect(await store.snapshot().workspaces.isEmpty)
        #expect(await mockRepository.loadFailuresRemaining == 0)
    }

    @Test("Failed reset propagates error")
    func failedReset() async {
        let mockRepository = MockSettingsRepository(
            shouldFailSave: true,
            loadFailuresRemaining: 1
        )

        await #expect(throws: SettingsRepositoryError.corruptedData(description: "save")) {
            try await SettingsStore.make(repository: mockRepository)
        }
    }

    @Test("Returns workspaces from store snapshot")
    func returnWorkspaces() async throws {
        var document: SettingsDocument = .empty
        document.workspaces = createMockWorkspace(count: 3)
        let mockRepository = MockSettingsRepository(
            document: document
        )
        let publisherSpy = SnapshotPublisherSpy()

        let manager = try #require(
            try? await makeManager(repository: mockRepository, publisher: publisherSpy)
        )
        #expect(await manager.getAvailableWorkspaces() == document.workspaces)
    }

    @Test("Returns workspace when id exists")
    func validIdGetWorkspace() async throws {
        var document: SettingsDocument = .empty
        document.workspaces = createMockWorkspace(count: 3)
        let mockRepository = MockSettingsRepository(
            document: document
        )
        let publisherSpy = SnapshotPublisherSpy()

        let manager = try #require(
            try? await makeManager(repository: mockRepository, publisher: publisherSpy)
        )
        let target = document.workspaces[0]
        #expect(await manager.getWorkspace(id: target.id) == target)
    }

    @Test("Returns nil when id is missing")
    func invalidIdGetWorkspace() async throws {
        var document: SettingsDocument = .empty
        document.workspaces = createMockWorkspace(count: 3)
        let mockRepository = MockSettingsRepository(
            document: document
        )
        let publisherSpy = SnapshotPublisherSpy()

        let manager = try #require(
            try? await makeManager(repository: mockRepository, publisher: publisherSpy)
        )
        #expect(await manager.getWorkspace(id: UUID()) == nil)
    }

    private func makeManager(
        repository: MockSettingsRepository,
        publisher: SnapshotPublisherSpy
    ) async throws -> WorkspaceCatalog {
        let store = try await SettingsStore.make(repository: repository)
        return WorkspaceCatalog(store: store, snapshotPublisher: publisher)
    }

    private func createMockWorkspace(count: Int) -> [Workspace] {
        var res: [Workspace] = []
        for index in 1...count {
            res.append(Workspace(name: "placeholder: \(index)", symbol: "test", applications: []))
        }
        return res
    }

    @Test("Create publishes the created snapshot")
    func createPublishesTheCreatedSnapshot() async throws {
        let mockRepository = MockSettingsRepository()
        let publisherSpy = SnapshotPublisherSpy()

        let manager = try #require(
            try? await makeManager(repository: mockRepository, publisher: publisherSpy)
        )

        let createdWorkspace = try await manager.createWorkspace(name: "Placeholder", symbol: "book", applications: [])

        #expect(publisherSpy.publishedSnapshots == [[createdWorkspace]])
    }

    @Test("Update publishes the updated snapshot")
    func updatePublishesTheUpdatedSnapshot() async throws {
        let publisherSpy = SnapshotPublisherSpy()

        var workspace = Workspace(name: "Placeholder", symbol: "book")

        var document: SettingsDocument = .empty
        document.workspaces = [workspace]

        let mockRepository = MockSettingsRepository(document: document)

        let manager = try #require(
            try? await makeManager(repository: mockRepository, publisher: publisherSpy)
        )

        workspace.name = "Placeholder 2"

        try await manager.updateWorkspace(workspace)

        #expect(publisherSpy.publishedSnapshots == [[workspace]])
    }

    @Test("Delete publishes the remaining workspaces")
    func deletePublishesTheRemainingWorkspaces() async throws {
        let deletedWorkspace = Workspace(
            name: "Deleted",
            symbol: "trash"
        )
        let remainingWorkspace = Workspace(
            name: "Placeholder",
            symbol: "book"
        )

        var document: SettingsDocument = .empty
        document.workspaces = [deletedWorkspace, remainingWorkspace]

        let mockRepository = MockSettingsRepository(document: document)
        let publisherSpy = SnapshotPublisherSpy()

        let manager = try #require(
            try? await makeManager(repository: mockRepository, publisher: publisherSpy)
        )

        try await manager.deleteWorkspace(id: deletedWorkspace.id)

        #expect(publisherSpy.publishedSnapshots == [[remainingWorkspace]])
    }

    @Test("Validation failure does not publish")
    func validationFailureDoesNotPublish() async throws {
        let repository = MockSettingsRepository()
        let publisher = SnapshotPublisherSpy()
        let manager = try await makeManager(
            repository: repository,
            publisher: publisher
        )

        await #expect(throws: SettingsStoreError.emptyWorkspaceName) {
            _ = try await manager.createWorkspace(
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
        let manager = try await makeManager(
            repository: repository,
            publisher: publisher
        )

        await repository.setShouldFailSave(true)

        await #expect(
            throws: SettingsRepositoryError.corruptedData(
                description: "save"
            )
        ) {
            _ = try await manager.createWorkspace(
                name: "Placeholder",
                symbol: "book",
                applications: []
            )
        }

        #expect(publisher.publishedSnapshots.isEmpty)
        #expect(await manager.getAvailableWorkspaces().isEmpty)
    }

    @Test("Read operations do not publish")
    func readOperationsDoNotPublish() async throws {
        let workspace = Workspace(
            name: "Placeholder",
            symbol: "book",
            applications: []
        )

        var document: SettingsDocument = .empty
        document.workspaces = [workspace]

        let repository = MockSettingsRepository(document: document)
        let publisher = SnapshotPublisherSpy()
        let manager = try await makeManager(
            repository: repository,
            publisher: publisher
        )

        _ = await manager.getAvailableWorkspaces()
        _ = await manager.getWorkspace(id: workspace.id)
        _ = await manager.getWorkspace(id: UUID())

        #expect(publisher.publishedSnapshots.isEmpty)
    }

    @Test("Concurrent mutations publish monotonically newer snapshots")
    func concurrentMutationsPublishMonotonicSnapshots() async throws {
        let mutationCount = 100
        let repository = MockSettingsRepository()
        let publisher = SnapshotPublisherSpy()

        let manager = try await makeManager(
            repository: repository,
            publisher: publisher
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<mutationCount {
                group.addTask {
                    _ = try await manager.createWorkspace(
                        name: "Workspace \(index)",
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
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )
        let activeSince = Date(
            timeIntervalSince1970: 100
        )

        var document = SettingsDocument.empty
        document.workspaces = [workspace]
        document.workspaceActivity.activate(
            workspaceID: workspace.id,
            at: activeSince
        )

        let repository = MockSettingsRepository(
            document: document
        )
        let manager = try await makeManager(
            repository: repository,
            publisher: SnapshotPublisherSpy()
        )

        let activity = await manager.getWorkspaceActivity()

        #expect(activity.activeWorkspaceID == workspace.id)
        #expect(activity.activeSince == activeSince)
    }

    @Test("recording activation returns and persists activity")
    func recordsWorkspaceActivity() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )
        let activatedAt = Date(
            timeIntervalSince1970: 100
        )

        var document = SettingsDocument.empty
        document.workspaces = [workspace]

        let repository = MockSettingsRepository(
            document: document
        )
        let manager = try await makeManager(
            repository: repository,
            publisher: SnapshotPublisherSpy()
        )

        let activity = try await manager.recordWorkspaceActivation(
            workspaceID: workspace.id,
            at: activatedAt
        )

        #expect(activity.activeWorkspaceID == workspace.id)
        #expect(activity.activeSince == activatedAt)
        #expect(
            await repository.document?.workspaceActivity
                == activity
        )
    }

    @Test("stopping returns and persists inactive activity")
    func stopsWorkspaceActivity() async throws {
        let workspace = Workspace(
            name: "Work",
            symbol: "briefcase"
        )
        let stoppedAt = Date(
            timeIntervalSince1970: 200
        )

        var document = SettingsDocument.empty
        document.workspaces = [workspace]
        document.workspaceActivity.activate(
            workspaceID: workspace.id,
            at: Date(timeIntervalSince1970: 100)
        )

        let repository = MockSettingsRepository(
            document: document
        )
        let manager = try await makeManager(
            repository: repository,
            publisher: SnapshotPublisherSpy()
        )

        let activity = try await manager.stopActiveWorkspace(
            at: stoppedAt
        )

        #expect(activity.activeWorkspaceID == nil)
        #expect(
            activity.lastActiveAt(for: workspace.id)
                == stoppedAt
        )
        #expect(
            await repository.document?.workspaceActivity
                == activity
        )
    }

    @Test("Retrieval returns active and archived workspaces in stored order")
    func retrievalKeepsStoredOrder() async throws {
        let study = Workspace(name: "Study", symbol: "book")
        let archived = Workspace(
            name: "Old",
            symbol: "archivebox",
            isArchived: true
        )
        let games = Workspace(name: "Games", symbol: "gamecontroller")

        var document: SettingsDocument = .empty
        document.workspaces = [study, archived, games]

        let manager = try await makeManager(
            repository: MockSettingsRepository(document: document),
            publisher: SnapshotPublisherSpy()
        )

        #expect(await manager.getAvailableWorkspaces() == [study, archived, games])
        #expect(await manager.getWorkspace(id: archived.id) == archived)
    }

    @Test("Archive publishes the stored list with the flag set")
    func archivePublishesStoredList() async throws {
        let study = Workspace(name: "Study", symbol: "book")
        let games = Workspace(name: "Games", symbol: "gamecontroller")

        var document: SettingsDocument = .empty
        document.workspaces = [study, games]

        let publisher = SnapshotPublisherSpy()
        let manager = try await makeManager(
            repository: MockSettingsRepository(document: document),
            publisher: publisher
        )

        try await manager.archiveWorkspace(id: study.id)

        let archivedStudy = Workspace(
            id: study.id,
            name: study.name,
            symbol: study.symbol,
            isArchived: true
        )

        #expect(publisher.publishedSnapshots == [[archivedStudy, games]])
    }

    @Test("Unarchive publishes the stored list with the flag cleared")
    func unarchivePublishesStoredList() async throws {
        let study = Workspace(name: "Study", symbol: "book")
        let archived = Workspace(
            name: "Old",
            symbol: "archivebox",
            isArchived: true
        )

        var document: SettingsDocument = .empty
        document.workspaces = [study, archived]

        let publisher = SnapshotPublisherSpy()
        let manager = try await makeManager(
            repository: MockSettingsRepository(document: document),
            publisher: publisher
        )

        try await manager.unarchiveWorkspace(id: archived.id)

        let restored = Workspace(
            id: archived.id,
            name: archived.name,
            symbol: archived.symbol
        )

        #expect(publisher.publishedSnapshots == [[study, restored]])
    }

    @Test("Missing archive does not publish")
    func missingArchiveDoesNotPublish() async throws {
        let publisher = SnapshotPublisherSpy()
        let manager = try await makeManager(
            repository: MockSettingsRepository(),
            publisher: publisher
        )
        let missingID = UUID()

        await #expect(throws: SettingsStoreError.workspaceNotFound(missingID)) {
            try await manager.archiveWorkspace(id: missingID)
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

@MainActor
final class SnapshotPublisherSpy: WorkspaceSnapshotPublishing {
    private(set) var publishedSnapshots: [[Workspace]] = []
    private(set) var publishedActivities: [WorkspaceActivityState] = []

    func publishAvailableWorkspaces(
        _ workspaces: [libdawn.Workspace],
        activity: WorkspaceActivityState
    ) {
        publishedSnapshots.append(workspaces)
        publishedActivities.append(activity)
    }
}
