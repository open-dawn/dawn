import Foundation

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
