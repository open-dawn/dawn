//
//  MenuBarVisibilityListenerTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 28/10/26.
//

import Testing
import libdawn

@testable import dawnAgent

@MainActor
@Suite("Menu bar visibility listener")
struct MenuBarVisibilityListenerTests {
    @Test("Get returns persisted visibility")
    func getReturnsPersistedVisibility() async throws {
        let bus = EventBus()
        let store = MenuBarVisibilityStoreSpy(
            isVisible: false
        )
        let controller = MenuBarControllerSpy(
            isVisible: true
        )

        let listener = MenuBarVisibilityListener(
            bus: bus,
            store: store,
            menuBarController: controller
        )

        let response = try await bus.ask(
            .getMenuBarVisibility(
                GetMenuBarVisibilityEvent()
            ),
            timeout: .seconds(1)
        )

        #expect(
            response == .menuBarVisibilityState(
                MenuBarVisibilityStateEvent(
                    isVisible: false
                )
            )
        )

        #expect(await store.requestedVisibilities.isEmpty)
        #expect(controller.visibilityChanges.isEmpty)

        _ = listener
    }

    @Test("Set persists, updates controller and publishes state")
    func setUpdatesVisibility() async throws {
        let bus = EventBus()
        let store = MenuBarVisibilityStoreSpy(
            isVisible: true
        )
        let controller = MenuBarControllerSpy(
            isVisible: true
        )
        let stateRecorder =
            MenuBarVisibilityStateRecorder()

        bus.addListener(
            stateRecorder,
            kinds: [.menuBarVisibilityState]
        )

        let listener = MenuBarVisibilityListener(
            bus: bus,
            store: store,
            menuBarController: controller
        )

        let response = try await bus.ask(
            .setMenuBarVisibility(
                SetMenuBarVisibilityEvent(
                    isVisible: false
                )
            ),
            timeout: .seconds(1)
        )

        await stateRecorder.waitForFirstState()

        #expect(
            response
                == .menuBarVisibilityMutationAcknowledged(
                    .success(isVisible: false)
                )
        )

        #expect(
            await store.requestedVisibilities == [false]
        )
        #expect(!(await store.menuBarIsVisible()))
        #expect(controller.visibilityChanges == [false])

        #expect(
            stateRecorder.states == [
                MenuBarVisibilityStateEvent(
                    isVisible: false
                ),
            ]
        )

        _ = listener
    }

    @Test("Persistence failure does not update controller")
    func persistenceFailureDoesNotUpdateController()
        async throws
    {
        let bus = EventBus()
        let store = MenuBarVisibilityStoreSpy(
            isVisible: true,
            setError: SettingsRepositoryError
                .encodingFailed(
                    description: "Expected failure"
                )
        )
        let controller = MenuBarControllerSpy(
            isVisible: true
        )
        let stateRecorder =
            MenuBarVisibilityStateRecorder()

        bus.addListener(
            stateRecorder,
            kinds: [.menuBarVisibilityState]
        )

        let listener = MenuBarVisibilityListener(
            bus: bus,
            store: store,
            menuBarController: controller
        )

        let response = try await bus.ask(
            .setMenuBarVisibility(
                SetMenuBarVisibilityEvent(
                    isVisible: false
                )
            ),
            timeout: .seconds(1)
        )

        await Task.yield()

        #expect(
            response
                == .menuBarVisibilityMutationAcknowledged(
                    .failure(.persistence)
                )
        )

        #expect(await store.menuBarIsVisible())
        #expect(controller.visibilityChanges.isEmpty)
        #expect(stateRecorder.states.isEmpty)

        _ = listener
    }

    @Test("Setting existing value is idempotent")
    func settingExistingValueIsIdempotent()
        async throws
    {
        let bus = EventBus()
        let store = MenuBarVisibilityStoreSpy(
            isVisible: false
        )
        let controller = MenuBarControllerSpy(
            isVisible: true
        )
        let stateRecorder =
            MenuBarVisibilityStateRecorder()

        bus.addListener(
            stateRecorder,
            kinds: [.menuBarVisibilityState]
        )

        let listener = MenuBarVisibilityListener(
            bus: bus,
            store: store,
            menuBarController: controller
        )

        let response = try await bus.ask(
            .setMenuBarVisibility(
                SetMenuBarVisibilityEvent(
                    isVisible: false
                )
            ),
            timeout: .seconds(1)
        )

        await Task.yield()

        #expect(
            response
                == .menuBarVisibilityMutationAcknowledged(
                    .success(isVisible: false)
                )
        )

        #expect(await store.requestedVisibilities.isEmpty)
        #expect(controller.visibilityChanges == [false])
        #expect(stateRecorder.states.isEmpty)

        _ = listener
    }
}

private actor MenuBarVisibilityStoreSpy:
    MenuBarVisibilityStoring
{
    private var isVisible: Bool
    private let setError: (any Error)?

    private(set) var requestedVisibilities: [Bool] = []

    init(
        isVisible: Bool,
        setError: (any Error)? = nil
    ) {
        self.isVisible = isVisible
        self.setError = setError
    }

    func menuBarIsVisible() async -> Bool {
        isVisible
    }

    func setMenuBarVisible(
        _ isVisible: Bool
    ) async throws {
        requestedVisibilities.append(isVisible)

        if let setError {
            throw setError
        }

        self.isVisible = isVisible
    }
}

@MainActor
private final class MenuBarControllerSpy:
    MenuBarControlling
{
    private(set) var isVisible: Bool
    private(set) var visibilityChanges: [Bool] = []
    private(set) var stopCallCount = 0

    init(isVisible: Bool) {
        self.isVisible = isVisible
    }

    func setVisible(_ isVisible: Bool) {
        self.isVisible = isVisible
        visibilityChanges.append(isVisible)
    }

    func stop() {
        stopCallCount += 1
        isVisible = false
    }
}

@MainActor
private final class MenuBarVisibilityStateRecorder:
    Listener
{
    private(set) var states:
        [MenuBarVisibilityStateEvent] = []

    private var firstStateWaiter:
        CheckedContinuation<Void, Never>?

    func handle(
        _ event: Event,
        reply: (@Sendable (Event) -> Void)?
    ) {
        guard case .menuBarVisibilityState(let state) = event else {
            return
        }

        states.append(state)

        firstStateWaiter?.resume()
        firstStateWaiter = nil
    }

    func waitForFirstState() async {
        guard states.isEmpty else {
            return
        }

        await withCheckedContinuation {
            firstStateWaiter = $0
        }
    }
}
