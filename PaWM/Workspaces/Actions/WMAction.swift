import PaEventKit

protocol WMAction {
    var app: WorkspaceApplication { get }
    func execute() async throws(WMActionError)
}