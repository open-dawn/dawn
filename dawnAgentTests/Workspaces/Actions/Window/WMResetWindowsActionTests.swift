import AppKit
import Foundation
import libdawn
@testable import dawnAgent
import Testing

@Suite("WMResetWindowsAction Testing")
struct WMResetWindowsActionTests {
    @Test("success reset windows")
    func successReset() throws {
        let mockWorkspaceProvider = FakeWorkspaceProvider()
        let action = WMResetWindowsAction(workspace: mockWorkspaceProvider)
        #expect(throws: Never.self) { try action.execute() }
        #expect(mockWorkspaceProvider.calls == 1)
    }
}

final class FakeWorkspaceProvider: GlobalWorkspaceProvider {
    private(set) var calls: Int = 0

    func hideOtherApplications() {
        calls += 1
    }
}
