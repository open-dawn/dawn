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
    func corruptedRepository() async {
        var mockRepository = MockSettingsRepository()
        mockRepository.shouldFailLoad = true
        mockRepository.shouldFailLoadSwitchValue = true

        await #expect(throws: Never.self) {
            try await ContextManager(repository: mockRepository)
        }
    }

    @Test("Failed reset propagates error")
    func failedReset() async {
        var mockRepository = MockSettingsRepository()
        mockRepository.shouldFailLoad = true
        mockRepository.shouldFailSave = true

        await #expect(throws: SettingsRepositoryError.corruptedData(description: "load")) {
            try await ContextManager(repository: mockRepository)
        }
    }

    @Test("Returns contexts from store snapshot")
    func returnContexts() {}

    @Test("Returns context when id exists")
    func validIdGetContext() {}

    @Test("Returns nil when id is missing")
    func invalidIdGetContext() {}
}

struct MockSettingsRepository: SettingsRepository {
    var shouldFailLoad: Bool = false
    var shouldFailSave: Bool = false
    var shouldFailLoadSwitchValue: Bool = false
    var document: SettingsDocument?

    mutating func load() async throws -> SettingsDocument? {
        guard !shouldFailLoad else {
            if shouldFailLoadSwitchValue {
                shouldFailLoad.toggle()
            }
            throw SettingsRepositoryError.corruptedData(description: "load")
        }
        return document
    }

    func save(_: SettingsDocument) async throws {
        guard !shouldFailSave else { throw SettingsRepositoryError.corruptedData(description: "save") }
    }
}
