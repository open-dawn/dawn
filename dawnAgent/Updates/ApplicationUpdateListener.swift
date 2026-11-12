//
//  ApplicationUpdateListener.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

import libdawn

@MainActor
final class ApplicationUpdateListener: Listener {
    private let preparer: any AgentUpdatePreparing

    init(bus: EventBus, preparer: any AgentUpdatePreparing) {
        self.preparer = preparer

        bus.addListener(self, kinds: [
            .getComponentIdentity,
            .prepareForApplicationUpdate,
        ])
    }

    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?) {
        switch event {
        case .getComponentIdentity:
            reply?(
                .componentIdentity(
                    ComponentIdentityEvent(identity: preparer.identity)
                )
            )

        case .prepareForApplicationUpdate:
            handlePreparation(reply: reply)

        default:
            return
        }
    }

    private func handlePreparation(reply: (@Sendable (Event) -> Void)?) {
        guard let reply else { return }

        Task { @MainActor in
            do {
                try await preparer.prepareForApplicationUpdate()

                reply(
                    .applicationUpdatePreparationAcknowledged(
                        .ready(identity: preparer.identity)
                    )
                )
            } catch {
                reply(
                    .applicationUpdatePreparationAcknowledged(
                        .failure(failure: .workspaceShutdownFailed)
                    )
                )
            }
        }
    }
}
