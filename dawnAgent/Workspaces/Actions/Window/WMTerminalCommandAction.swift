import Foundation

struct WMTerminalCommandAction: WMAction {
    let command: String
    private let runner: TerminalCommandRunning

    init(command: String, runner: TerminalCommandRunning = ProcessTerminalCommandRunner()) {
        self.command = command
        self.runner = runner
    }

    func execute() async throws(WMActionError) {
        do {
            try await runner.run(command: command)
        } catch let error as WMActionError {
            throw error
        } catch {
            throw WMActionError.unknown(reason: error.localizedDescription)
        }
    }
}
