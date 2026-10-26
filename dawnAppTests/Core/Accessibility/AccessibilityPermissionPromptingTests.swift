import Foundation
import libdawn
import Testing

@testable import dawnApp

@MainActor
private final class FakeAccessibilityEventBus: SettingsContextEventBus {
    var askHandler: ((Event) async throws -> Event)?

    func addListener(_: any Listener, kinds _: Set<EventKind>?) {}

    func removeListener(_: any Listener) {}

    func ask(_ event: Event, timeout _: Duration) async throws -> Event {
        guard let askHandler else {
            throw AccessibilityPermissionError.requestFailed("missing ask handler")
        }

        return try await askHandler(event)
    }
}

@MainActor
@Suite("AccessibilityPermissionPrompting")
struct AccessibilityPermissionPromptingTests {
    @Test("fetchAccessibilityTrustStatus returns trusted flag")
    func fetchStatus() async throws {
        let bus = FakeAccessibilityEventBus()
        bus.askHandler = { event in
            #expect(event.kind == .getAccessibilityStatus)
            return .accessibilityStatus(AccessibilityStatusEvent(isTrusted: true))
        }

        let isTrusted = try await fetchAccessibilityTrustStatus(using: bus)
        #expect(isTrusted)
    }

    @Test("promptAccessibilityTrust returns prompt result")
    func promptTrust() async throws {
        let bus = FakeAccessibilityEventBus()
        bus.askHandler = { event in
            #expect(event.kind == .promptAccessibilityTrust)
            return .accessibilityStatus(AccessibilityStatusEvent(isTrusted: false))
        }

        let isTrusted = try await promptAccessibilityTrust(using: bus)
        #expect(!isTrusted)
    }

    @Test("unexpected reply throws")
    func unexpectedReply() async {
        let bus = FakeAccessibilityEventBus()
        bus.askHandler = { _ in
            .debugPong(DebugPongEvent(message: "nope"))
        }

        await #expect(throws: AccessibilityPermissionError.unexpectedResponse(.debugPong)) {
            try await fetchAccessibilityTrustStatus(using: bus)
        }
    }
}

@MainActor
@Suite("AccessibilityPermissionService")
struct AccessibilityPermissionServiceTests {
    @Test("refresh stores trusted status")
    func refreshStoresStatus() async {
        let bus = FakeAccessibilityEventBus()
        bus.askHandler = { _ in
            .accessibilityStatus(AccessibilityStatusEvent(isTrusted: true))
        }

        let service = AccessibilityPermissionService(bus: bus)
        await service.refresh()

        #expect(service.isTrusted == true)
        #expect(service.error == nil)
    }

    @Test("promptTrust stores failure error")
    func promptTrustStoresError() async {
        let bus = FakeAccessibilityEventBus()
        bus.askHandler = { _ in
            throw AccessibilityPermissionError.requestFailed("offline")
        }

        let service = AccessibilityPermissionService(bus: bus)
        let result = await service.promptTrust()

        #expect(!result)
        #expect(service.error == .requestFailed("offline"))
    }
}
