import libdawn

protocol WMAction {
    func execute() async throws(WMActionError)
}
