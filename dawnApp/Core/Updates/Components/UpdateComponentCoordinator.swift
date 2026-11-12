//
//  UpdateComponentCoordinator.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

import Foundation

@MainActor
protocol UpdateComponent {
    var identifier: String { get }

    func prepareForUpdate(targetBuild: String) async throws

    func recoverAfterUpdateFailure() async throws

    func reconcileAfterUpdate(expectedBuild: String) async throws
}

@MainActor
protocol UpdateComponentCoordinating {
    func prepareForUpdate(_ update: AvailableAppUpdate) async throws

    func recoverAfterUpdateFailure() async throws

    func reconcileAfterUpdate(expectedBuild: String) async throws
}

enum UpdateComponentCoordinatorError: Error, Equatable {
    case preparationAlreadyInProgress
}

@MainActor
final class UpdateComponentCoordinator: UpdateComponentCoordinating {
    private let components: [any UpdateComponent]

    private var preparedComponents: [any UpdateComponent] = []

    init(components: [any UpdateComponent]) {
        self.components = components
    }

    func prepareForUpdate(_ update: AvailableAppUpdate) async throws {
        guard preparedComponents.isEmpty else {
            throw UpdateComponentCoordinatorError.preparationAlreadyInProgress
        }

        for component in components {
            preparedComponents.append(component)

            try await component.prepareForUpdate(targetBuild: update.buildVersion)
        }
    }

    func recoverAfterUpdateFailure() async throws {
        guard !preparedComponents.isEmpty else {
            return
        }

        for component in preparedComponents.reversed() {
            try await component.recoverAfterUpdateFailure()
        }

        preparedComponents.removeAll()
    }

    func reconcileAfterUpdate(expectedBuild: String) async throws {
        for component in components {
            try await component.reconcileAfterUpdate(expectedBuild: expectedBuild)
        }
    }
}
