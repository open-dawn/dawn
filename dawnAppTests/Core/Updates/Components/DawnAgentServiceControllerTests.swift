//
//  DawnAgentServiceControllerTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

import ServiceManagement
import Testing

@testable import dawnApp

@MainActor
@Suite("DawnAgentServiceController")
struct DawnAgentServiceControllerTests {
    @Test("Enabled service is unregistered")
    func enabledServiceIsUnregistered() async throws {
        let service = LoginItemServiceSpy(
            status: .enabled
        )

        let controller = DawnAgentServiceController(
            service: service
        )

        try await controller.deactivateForUpdate()

        #expect(service.unregisterCallCount == 1)
    }

    @Test("Service requiring approval is unregistered")
    func approvalServiceIsUnregistered() async throws {
        let service = LoginItemServiceSpy(
            status: .requiresApproval
        )

        let controller = DawnAgentServiceController(
            service: service
        )

        try await controller.deactivateForUpdate()

        #expect(service.unregisterCallCount == 1)
    }

    @Test("Unregistered service requires no operation")
    func unregisteredServiceIsIgnored() async throws {
        let service = LoginItemServiceSpy(
            status: .notRegistered
        )

        let controller = DawnAgentServiceController(
            service: service
        )

        try await controller.deactivateForUpdate()

        #expect(service.unregisterCallCount == 0)
    }

    @Test("Missing service requires no operation")
    func missingServiceIsIgnored() async throws {
        let service = LoginItemServiceSpy(
            status: .notFound
        )

        let controller = DawnAgentServiceController(
            service: service
        )

        try await controller.deactivateForUpdate()

        #expect(service.unregisterCallCount == 0)
    }

    @Test("Unregister failure is propagated")
    func unregisterFailureIsPropagated() async {
        let service = LoginItemServiceSpy(
            status: .enabled
        )
        service.unregisterError = ServiceTestError.expected

        let controller = DawnAgentServiceController(
            service: service
        )

        await #expect(throws: ServiceTestError.expected) {
            try await controller.deactivateForUpdate()
        }

        #expect(service.unregisterCallCount == 1)
    }

    @Test("Deactivation waits for unregister completion")
    func waitsForCompletion() async throws {
        let service = LoginItemServiceSpy(
            status: .enabled
        )
        service.completesImmediately = false

        let controller = DawnAgentServiceController(
            service: service
        )

        let completion = CompletionState()

        let task = Task { @MainActor in
            try await controller.deactivateForUpdate()
            completion.didFinish = true
        }

        await Task.yield()

        #expect(service.unregisterCallCount == 1)
        #expect(!completion.didFinish)

        service.completeUnregister()
        try await task.value

        #expect(completion.didFinish)
    }

    @Test("Recovery restores a previously enabled agent")
    func recoveryRestoresEnabledAgent() async throws {
        let service = LoginItemServiceSpy(status: .enabled)
        let controller = DawnAgentServiceController(
            service: service
        )

        try await controller.deactivateForUpdate()
        try await controller.restoreRegistration(.enabled)

        #expect(service.unregisterCallCount == 1)
        #expect(service.registerCallCount == 1)
        #expect(service.status == .enabled)
    }

    @Test("Recovery restores a service awaiting approval")
    func recoveryRestoresApprovalState() async throws {
        let service = LoginItemServiceSpy(
            status: .requiresApproval
        )

        let controller = DawnAgentServiceController(
            service: service
        )

        try await controller.deactivateForUpdate()
        try await controller.restoreRegistration(
            .requiresApproval
        )

        #expect(service.unregisterCallCount == 1)
        #expect(service.registerCallCount == 1)
    }

    @Test("Recovery preserves an unregistered service")
    func recoveryPreservesUnregisteredState() async throws {
        let service = LoginItemServiceSpy(
            status: .notRegistered
        )

        let controller = DawnAgentServiceController(
            service: service
        )

        try await controller.restoreRegistration(
            .notRegistered
        )

        #expect(service.unregisterCallCount == 0)
        #expect(service.registerCallCount == 0)
    }

    @Test("Recovery disables a service that was previously unregistered")
    func recoveryDisablesUnexpectedlyEnabledService() async throws {
        let service = LoginItemServiceSpy(status: .enabled)
        let controller = DawnAgentServiceController(
            service: service
        )

        try await controller.restoreRegistration(
            .notRegistered
        )

        #expect(service.unregisterCallCount == 1)
        #expect(service.registerCallCount == 0)
        #expect(service.status == .notRegistered)
    }

    @Test("Unknown registration state cannot be restored")
    func unknownRegistrationStateFails() async {
        let service = LoginItemServiceSpy(
            status: .notRegistered
        )

        let controller = DawnAgentServiceController(
            service: service
        )

        await #expect(
            throws:
                DawnAgentServiceControllerError
                .unknownRegistrationState
        ) {
            try await controller.restoreRegistration(.unknown)
        }

        #expect(service.registerCallCount == 0)
        #expect(service.unregisterCallCount == 0)
    }

    @Test("Registration restoration can be retried")
    func registrationRestorationCanBeRetried() async throws {
        let service = LoginItemServiceSpy(
            status: .notRegistered
        )
        service.registerError = ServiceTestError.expected

        let controller = DawnAgentServiceController(
            service: service
        )

        await #expect(throws: ServiceTestError.expected) {
            try await controller.restoreRegistration(.enabled)
        }

        service.registerError = nil

        try await controller.restoreRegistration(.enabled)

        #expect(service.registerCallCount == 2)
        #expect(service.status == .enabled)
    }

    @Test("Activation registers an unregistered agent")
    func activationRegistersAgent() throws {
        let service = LoginItemServiceSpy(
            status: .notRegistered
        )

        let controller = DawnAgentServiceController(
            service: service
        )

        try controller.activateIfNeeded()

        #expect(service.registerCallCount == 1)
        #expect(service.status == .enabled)
    }

    @Test("Activation does not register an enabled agent again")
    func activationDoesNotDuplicateRegistration() throws {
        let service = LoginItemServiceSpy(
            status: .enabled
        )

        let controller = DawnAgentServiceController(
            service: service
        )

        try controller.activateIfNeeded()

        #expect(service.registerCallCount == 0)
    }

    @Test("Reconciliation restart unregisters then registers agent")
    func reconciliationRestartReplacesAgent() async throws {
        let service = LoginItemServiceSpy(
            status: .enabled
        )

        let controller = DawnAgentServiceController(
            service: service
        )

        try await controller.restartForReconciliation()

        #expect(service.unregisterCallCount == 1)
        #expect(service.registerCallCount == 1)
        #expect(service.status == .enabled)
    }

    @Test("Restart propagates registration failure")
    func restartPropagatesRegistrationFailure() async {
        let service = LoginItemServiceSpy(
            status: .enabled
        )
        service.registerError = ServiceTestError.expected

        let controller = DawnAgentServiceController(
            service: service
        )

        await #expect(throws: ServiceTestError.expected) {
            try await controller.restartForReconciliation()
        }

        #expect(service.status == .notRegistered)
    }

    @Test("Reports every known service registration state")
    func reportsRegistrationState() {
        let enabled = DawnAgentServiceController(
            service: LoginItemServiceSpy(status: .enabled)
        )

        let approval = DawnAgentServiceController(
            service: LoginItemServiceSpy(status: .requiresApproval)
        )

        let unregistered = DawnAgentServiceController(
            service: LoginItemServiceSpy(status: .notRegistered)
        )

        let missing = DawnAgentServiceController(
            service: LoginItemServiceSpy(status: .notFound)
        )

        #expect(enabled.registrationState == .enabled)
        #expect(approval.registrationState == .requiresApproval)
        #expect(unregistered.registrationState == .notRegistered)
        #expect(missing.registrationState == .notFound)
    }
}

@MainActor
private final class LoginItemServiceSpy:
    DawnAgentLoginItemServicing
{
    var status: SMAppService.Status
    var unregisterError: Error?
    var completesImmediately = true
    var registerError: Error?

    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    private(set) var operations: [String] = []

    private var pendingCompletion: (@Sendable (Error?) -> Void)?

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        operations.append("register")

        if let registerError {
            throw registerError
        }

        status = .enabled
    }

    func unregister(
        completionHandler:
            @escaping @Sendable (Error?) -> Void
    ) {
        unregisterCallCount += 1
        operations.append("unregister")

        if completesImmediately {
            let error = unregisterError

            if error == nil {
                status = .notRegistered
            }

            completionHandler(error)
        } else {
            pendingCompletion = completionHandler
        }
    }

    func completeUnregister(error: Error? = nil) {
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(error)
    }
}

@MainActor
private final class CompletionState {
    var didFinish = false
}

private enum ServiceTestError: Error, Equatable {
    case expected
}
