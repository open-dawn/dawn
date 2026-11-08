import ServiceManagement
import Testing
@testable import dawnApp

@Suite("Agent login item action")
struct AgentLoginItemActionTests {
    @Test("Leaves a running agent registered")
    func leavesRunningAgentRegistered() {
        #expect(
            AgentLoginItemAction.resolve(
                isAgentRunning: true,
                status: .enabled
            ) == .ensureRegistered
        )
    }

    @Test("Registers when the login item is missing")
    func registersWhenMissing() {
        #expect(
            AgentLoginItemAction.resolve(
                isAgentRunning: false,
                status: .notRegistered
            ) == .register
        )
    }

    @Test("Bounces when registered after a clean agent quit")
    func bouncesWhenRegisteredButNotRunning() {
        #expect(
            AgentLoginItemAction.resolve(
                isAgentRunning: false,
                status: .enabled
            ) == .bounce
        )
    }

    @Test("Waits when the login item still needs approval")
    func waitsForApproval() {
        #expect(
            AgentLoginItemAction.resolve(
                isAgentRunning: false,
                status: .requiresApproval
            ) == .waitForApproval
        )
    }
}
