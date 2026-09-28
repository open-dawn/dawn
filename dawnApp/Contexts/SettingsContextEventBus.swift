//
//  SettingsContextEventBus.swift
//  dawn
//
//  Created by Rafael Venetikides on 22/09/26.
//

import libdawn

@MainActor
protocol SettingsContextEventBus: AnyObject {
    func addListener(_ listener: Listener, kinds: Set<EventKind>?)

    func removeListener(_ listener: Listener)

    func ask(_ event: Event, timeout: Duration) async throws -> Event
}

extension RemoteEventBus: SettingsContextEventBus {}
