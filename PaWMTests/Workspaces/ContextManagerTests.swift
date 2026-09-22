import Foundation
import PaEventKit
@testable import PaWM
import Testing

@Suite("ContextManager")
struct ContextManagerTests {
    @Test("Valid repository loads contexts")
    func validRepository() async {
        let mockRepository = MockSettingsRepository()

        await #expect(throws: Never.self) {
            try await ContextManager(repository: mockRepository)
        }
    }

    @Test("Corrupted repository resets to empty")
    func corruptedRepository() async throws {
        let mockRepository = MockSettingsRepository(loadFailuresRemaining: 1)
        let manager = try await ContextManager(repository: mockRepository)

        #expect(await manager.getAvailableContexts().isEmpty)
        #expect(await mockRepository.loadFailuresRemaining == 0)
    }

    @Test("Failed reset propagates error")
    func failedReset() async {
        let mockRepository = MockSettingsRepository(
            shouldFailSave: true,
            loadFailuresRemaining: 1
        )

        await #expect(throws: SettingsRepositoryError.corruptedData(description: "save")) {
            try await ContextManager(repository: mockRepository)
        }
    }

    @Test("Returns contexts from store snapshot")
    func returnContexts() async throws {
        var document: SettingsDocument = .empty
        document.contexts = createMockWorkspaceContext(count: 3)
        let mockRepository = MockSettingsRepository(
            document: document
        )

        let manager = try #require(try? await ContextManager(repository: mockRepository))
        #expect(await manager.getAvailableContexts() == document.contexts)
    }

    @Test("Returns context when id exists")
    func validIdGetContext() async throws {
        var document: SettingsDocument = .empty
        document.contexts = createMockWorkspaceContext(count: 3)
        let mockRepository = MockSettingsRepository(
            document: document
        )

        let manager = try #require(try? await ContextManager(repository: mockRepository))
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

        let manager = try #require(try? await ContextManager(repository: mockRepository))
        #expect(await manager.getContext(id: UUID()) == nil)
    }

    private func createMockWorkspaceContext(count: Int) -> [WorkspaceContext] {
        var res: [WorkspaceContext] = []
        for index in 1 ... count {
            res.append(WorkspaceContext(name: "placeholder: \(index)", symbol: "test", applications: []))
        }
        return res
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
