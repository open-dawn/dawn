//
//  ContextSnapshotPublisher.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 22/09/26.
//

import libdawn

@MainActor
protocol ContextSnapshotPublishing: AnyObject {
    func publishAvailableContexts(_ contexts: [WorkspaceContext])
}

@MainActor
final class EventBusContextSnapshotPublisher: ContextSnapshotPublishing {
    private let bus: EventBus

    init(bus: EventBus) {
        self.bus = bus
    }

    func publishAvailableContexts(_ contexts: [WorkspaceContext]) {
        bus.publish(
            .availableContexts(
                AvailableContextsEvent(contexts: contexts)
            )
        )
    }
}
