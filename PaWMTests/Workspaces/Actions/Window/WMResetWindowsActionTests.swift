import AppKit
import Foundation
import PaEventKit
@testable import PaWM
import Testing

@Suite("WMResetWindowsAction Testing")
struct WMResetWindowsActionTests {
    @Test("success reset windows")
    func successReset() throws {
        let action = WMResetWindowsAction()
        #expect(throws: Never.self) { try action.execute() }
    }
}
