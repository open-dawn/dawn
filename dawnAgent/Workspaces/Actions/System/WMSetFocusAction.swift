// CURSOR: NEED REVIEW
import Foundation

/// Best-effort enable of a macOS Focus mode (e.g. Do Not Disturb).
struct WMSetFocusAction: WMAction {
    let focusModeName: String
    private let applicator: FocusModeApplying

    init(
        focusModeName: String,
        applicator: FocusModeApplying = ShortcutsFocusModeApplicator()
    ) {
        self.focusModeName = focusModeName
        self.applicator = applicator
    }

    func execute() throws(WMActionError) {
        do {
            try applicator.applyFocusMode(named: focusModeName)
        } catch let error as WMActionError {
            throw error
        } catch {
            throw WMActionError.unknown(reason: error.localizedDescription)
        }
    }
}
