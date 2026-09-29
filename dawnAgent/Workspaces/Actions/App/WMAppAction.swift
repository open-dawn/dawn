import libdawn

protocol WMAppAction: WMAction {
    var app: WorkspaceApplication { get }
    func execute() async throws(WMActionError)
}
