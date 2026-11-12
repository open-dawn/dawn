//
//  DawnAgentServiceController.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

import ServiceManagement
import libdawn

@MainActor
protocol DawnAgentLoginItemServicing: AnyObject {
    var status: SMAppService.Status { get }

    func register() throws

    func unregister(completionHandler: @escaping @Sendable (Error?) -> Void)
}

extension SMAppService: DawnAgentLoginItemServicing {}

@MainActor
final class DawnAgentServiceController: DawnAgentServiceManaging {
    private let service: any DawnAgentLoginItemServicing

    private var needsReactivation = false

    convenience init() {
        self.init(
            service: SMAppService.loginItem(
                identifier: EventBusMachService.agentBundleIdentifier
            )
        )
    }

    init(service: any DawnAgentLoginItemServicing) {
        self.service = service
    }

    func activateIfNeeded() throws {
        switch service.status {
        case .enabled, .requiresApproval:
            return

        case .notRegistered, .notFound:
            try service.register()

        @unknown default:
            try service.register()
        }
    }

    func deactivateForUpdate() async throws {
        switch service.status {
        case .notRegistered, .notFound:
            return

        case .enabled, .requiresApproval:
            break

        @unknown default:
            break
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            service.unregister { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        needsReactivation = true
    }

    func reactivateAfterFailedUpdate() throws {
        guard needsReactivation else {
            return
        }

        try activateIfNeeded()
        needsReactivation = false
    }

    func restartForReconciliation() async throws {
        try await deactivateForUpdate()
        try activateIfNeeded()

        needsReactivation = false
    }
}
