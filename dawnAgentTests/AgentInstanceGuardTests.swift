import Testing
@testable import dawnAgent

@Suite("Agent instance guard")
struct AgentInstanceGuardTests {
    @Test("Continues when this process is the only instance")
    func continuesWhenAlone() {
        let guardValue = AgentInstanceGuard(
            currentProcessIdentifier: 10,
            runningProcessIdentifiers: [10]
        )

        #expect(!guardValue.shouldTerminate)
    }

    @Test("Continues when no instances are visible yet")
    func continuesWhenTheListIsEmpty() {
        let guardValue = AgentInstanceGuard(
            currentProcessIdentifier: 10,
            runningProcessIdentifiers: []
        )

        #expect(!guardValue.shouldTerminate)
    }

    @Test("Terminates when another instance is running")
    func terminatesWhenAnotherInstanceIsRunning() {
        let guardValue = AgentInstanceGuard(
            currentProcessIdentifier: 10,
            runningProcessIdentifiers: [10, 42]
        )

        #expect(guardValue.shouldTerminate)
    }
}
