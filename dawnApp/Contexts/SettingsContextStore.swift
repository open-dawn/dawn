//
//  SettingsContextStore.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 22/09/26.
//

import Foundation
import Observation
import libdawn

@Observable
@MainActor
final class SettingsContextStore: Listener {
    private let bus: any SettingsContextEventBus
    private var isStarted = false

    private(set) var contexts: [WorkspaceContext] = []
    private(set) var isLoading = false
    private(set) var error: SettingsContextStoreError?

    init(
        bus: any SettingsContextEventBus,
    ) {
        self.bus = bus
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        bus.addListener(
            self,
            kinds: [.availableContexts]
        )
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        bus.removeListener(self)
    }

    func dismissError() {
        error = nil
    }

    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?) {
        guard case .availableContexts(let payload) = event else {
            return
        }

        contexts = payload.contexts
        error = nil
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await bus.ask(
                .getContexts(GetContextsEvent()),
                timeout: .seconds(5)
            )

            switch response {
            case .contextsFetched(let payload):
                contexts = payload.contexts
                error = nil

            case .availableContexts(let payload):
                contexts = payload.contexts
                error = nil

            default:
                error = .unexpectedResponse(response.kind)
            }
        } catch {
            self.error = SettingsContextStoreError(error)
        }
    }

    private func askForAcknowledgement(_ event: Event, expectedContextID: UUID? = nil)
        async throws(SettingsContextStoreError) -> UUID
    {
        do {
            let response = try await bus.ask(event, timeout: .seconds(5))

            guard case .contextMutationAcknowledged(let acknowledgement) = response else {
                throw SettingsContextStoreError.unexpectedResponse(response.kind)
            }

            switch acknowledgement {
            case let .success(contextID):
                if let expectedContextID, contextID != expectedContextID {
                    throw
                        SettingsContextStoreError
                        .contextIdentifierMismatch(
                            expected: expectedContextID,
                            received: contextID
                        )
                }

                error = nil
                return contextID
            case .failure(let failure):
                throw SettingsContextStoreError.mutationRejected(failure)
            }
        } catch {
            let storeError = SettingsContextStoreError(error)
            self.error = storeError
            throw storeError
        }
    }

    @discardableResult
    func createContext(name: String, symbol: String, applications: [WorkspaceApplication])
        async throws(SettingsContextStoreError) -> UUID
    {
        try await askForAcknowledgement(
            .createContext(CreateContextEvent(name: name, symbol: symbol, applications: applications))
        )
    }

    func updateContext(_ context: WorkspaceContext) async throws(SettingsContextStoreError) {
        _ = try await askForAcknowledgement(
            .updateContext(UpdateContextEvent(context: context)),
            expectedContextID: context.id
        )
    }

    func deleteContext(id: UUID) async throws(SettingsContextStoreError) {
        _ = try await askForAcknowledgement(
            .deleteContext(
                DeleteContextEvent(
                    contextID: id
                )
            ),
            expectedContextID: id
        )
    }

    func switchContext(id: UUID) async throws(SettingsContextStoreError) {
        _ = try await askForAcknowledgement(
            .switchContext(SwitchContextEvent(contextID: id)),
            expectedContextID: id
        )
    }
}
