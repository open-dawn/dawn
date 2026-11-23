//
//  WorkspaceSnapshotPublisher.swift
//  dawn
//
//  Created by Rafael Venetikides on 22/09/26.
//

import libdawn

@MainActor
protocol WorkspaceSnapshotPublishing: AnyObject {
    func publishAvailableWorkspaces(
        _ workspaces: [Workspace],
        activity: WorkspaceActivityState
    )
}

@MainActor
final class EventBusWorkspaceSnapshotPublisher: WorkspaceSnapshotPublishing {
    private let bus: EventBus

    init(bus: EventBus) {
        self.bus = bus
    }

    func publishAvailableWorkspaces(
        _ workspaces: [Workspace],
        activity: WorkspaceActivityState
    ) {
        bus.publish(
            .availableWorkspaces(
                AvailableWorkspacesEvent(
                    workspaces: workspaces,
                    activity: activity
                )
            )
        )
    }
}
