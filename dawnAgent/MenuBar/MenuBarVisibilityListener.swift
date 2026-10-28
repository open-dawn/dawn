//
//  MenuBarVisibilityListener.swift
//  dawn
//
//  Created by Rafael Venetikides on 28/10/26.
//

import libdawn

@MainActor
final class MenuBarVisibilityListener: Listener {
    private let bus: EventBus
    private let store: any MenuBarVisibilityStoring
    private let menuBarController: any MenuBarControlling

    init(bus: EventBus, store: any MenuBarVisibilityStoring, menuBarController: any MenuBarControlling) {
        self.bus = bus
        self.store = store
        self.menuBarController = menuBarController

        bus.addListener(
            self,
            kinds: [
                .getMenuBarVisibility,
                .setMenuBarVisibility
            ]
        )
    }

    func handle(_ event: Event, reply: (@Sendable (Event) -> Void)?) {
        guard let reply else {
            return
        }

        switch event {
        case .getMenuBarVisibility:
            handleGet(reply: reply)
        case .setMenuBarVisibility(let payload):
            handleSet(payload, reply: reply)
        default:
            return
        }
    }
}

extension MenuBarVisibilityListener {
    private func handleGet(reply: @escaping @Sendable (Event) -> Void) {
        Task { @MainActor in
            let isVisible = await store.menuBarIsVisible()

            reply(
                .menuBarVisibilityState(
                    MenuBarVisibilityStateEvent(
                        isVisible: isVisible
                    )
                )
            )
        }
    }

    private func handleSet(_ payload: SetMenuBarVisibilityEvent, reply: @escaping @Sendable (Event) -> Void) {
        Task {@MainActor in
            let currentValue = await store.menuBarIsVisible()

            guard currentValue != payload.isVisible else {
                menuBarController.setVisible(currentValue)

                reply(
                    .menuBarVisibilityMutationAcknowledged(
                        .success(
                            isVisible: currentValue
                        )
                    )
                )

                return
            }

            do {
                try await store.setMenuBarVisible(
                    payload.isVisible
                )

                menuBarController.setVisible(
                    payload.isVisible
                )

                bus.publish(
                    .menuBarVisibilityState(
                        MenuBarVisibilityStateEvent(
                            isVisible: payload.isVisible
                        )
                    )
                )

                reply(
                    .menuBarVisibilityMutationAcknowledged(
                        .success(isVisible: payload.isVisible)
                    )
                )
            } catch {
                reply(
                    .menuBarVisibilityMutationAcknowledged(
                        .failure(
                            failure(from: error)
                        )
                    )
                )
            }
        }
    }

    private func failure(from error: Error) -> MenuBarVisibilityMutationAcknowledgement.Failure {
        if error is SettingsRepositoryError {
            return .persistence
        }

        return .unexpected
    }
}
