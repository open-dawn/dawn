// CURSOR: NEED REVIEW
import Foundation
@testable import dawnAgent
import Testing

@Suite("WMSetFocusAction Testing")
struct WMSetFocusActionTests {
    @Test("applies the named Focus mode")
    func appliesFocusMode() throws {
        let applicator = FakeFocusModeApplicator()
        let action = WMSetFocusAction(
            focusModeName: "Do Not Disturb",
            applicator: applicator
        )

        try action.execute()

        #expect(applicator.appliedNames == ["Do Not Disturb"])
    }

    @Test("maps applicator failures to unknown")
    func mapsFailure() {
        let applicator = FakeFocusModeApplicator()
        applicator.errorToThrow = NSError(domain: "test", code: 1)

        let action = WMSetFocusAction(
            focusModeName: "Work",
            applicator: applicator
        )

        #expect(throws: WMActionError.self) {
            try action.execute()
        }
    }
}

final class FakeFocusModeApplicator: FocusModeApplying {
    private(set) var appliedNames: [String] = []
    var errorToThrow: Error?

    func applyFocusMode(named name: String) throws {
        appliedNames.append(name)
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
