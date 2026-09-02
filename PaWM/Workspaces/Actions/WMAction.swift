import PaEventKit

protocol WMAction {
    func execute() async throws(WMActionError)
}
