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

enum DawnAgentServiceControllerError: Error, Equatable {
    case unknownRegistrationState
}

@MainActor
final class DawnAgentServiceController: DawnAgentServiceManaging {
    private let service: any DawnAgentLoginItemServicing

    var registrationState: UpdateComponentRegistrationState {
        switch service.status {
        case .notRegistered:
            .notRegistered

        case .enabled:
            .enabled

        case .requiresApproval:
            .requiresApproval

        case .notFound:
            .notFound

        @unknown default:
            .unknown
        }
    }

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

    }

    func restoreRegistration(_ state: UpdateComponentRegistrationState) async throws {
        switch state {
        case .enabled, .requiresApproval:
            try activateIfNeeded()

        case .notRegistered, .notFound:
            try await deactivateForUpdate()

        case .unknown:
            throw DawnAgentServiceControllerError.unknownRegistrationState
        }
    }

    func restartForReconciliation() async throws {
        try await deactivateForUpdate()
        try activateIfNeeded()
    }
}
