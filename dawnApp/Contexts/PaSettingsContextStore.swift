//
//  PaSettingsContextStore.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 22/09/26.
//

import Foundation
import Observation
import PaEventKit

@Observable
@MainActor
final class PaSettingsContextStore: Listener {
    private let bus: any PaSettingsContextEventBus
    private var isStarted = false

    private(set) var contexts: [WorkspaceContext] = []
    private(set) var isLoading = false
    private(set) var error: PaSettingsContextStoreError?

    init(
        bus: any PaSettingsContextEventBus,
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

    func handle(_ event: PaEvent, reply: (@Sendable (PaEvent) -> Void)?) {
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
                .getContexts(PaGetContextsEvent()),
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
            self.error = PaSettingsContextStoreError(error)
        }
    }

    private func askForAcknowledgement(_ event: PaEvent, expectedContextID: UUID? = nil)
        async throws(PaSettingsContextStoreError) -> UUID
    {
        do {
            let response = try await bus.ask(event, timeout: .seconds(5))

            guard case .contextMutationAcknowledged(let acknowledgement) = response else {
                throw PaSettingsContextStoreError.unexpectedResponse(response.kind)
            }

            switch acknowledgement {
            case let .success(contextID):
                if let expectedContextID, contextID != expectedContextID {
                    throw
                        PaSettingsContextStoreError
                        .contextIdentifierMismatch(
                            expected: expectedContextID,
                            received: contextID
                        )
                }

                error = nil
                return contextID
            case .failure(let failure):
                throw PaSettingsContextStoreError.mutationRejected(failure)
            }
        } catch {
            let storeError = PaSettingsContextStoreError(error)
            self.error = storeError
            throw storeError
        }
    }

    @discardableResult
    func createContext(name: String, symbol: String, applications: [WorkspaceApplication])
        async throws(PaSettingsContextStoreError) -> UUID
    {
        try await askForAcknowledgement(
            .createContext(PaCreateContextEvent(name: name, symbol: symbol, applications: applications))
        )
    }

    func updateContext(_ context: WorkspaceContext) async throws(PaSettingsContextStoreError) {
        _ = try await askForAcknowledgement(
            .updateContext(PaUpdateContextEvent(context: context)),
            expectedContextID: context.id
        )
    }

    func deleteContext(id: UUID) async throws(PaSettingsContextStoreError) {
        _ = try await askForAcknowledgement(
            .deleteContext(
                PaDeleteContextEvent(
                    contextID: id
                )
            ),
            expectedContextID: id
        )
    }

    func switchContext(id: UUID) async throws(PaSettingsContextStoreError) {
        _ = try await askForAcknowledgement(
            .switchContext(PaSwitchContextEvent(contextID: id)),
            expectedContextID: id
        )
    }
}
