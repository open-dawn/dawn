//
//  PaSettingsContextEventBus.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 22/09/26.
//

import PaEventKit

@MainActor
protocol PaSettingsContextEventBus: AnyObject {
    func addListener(_ listener: Listener, kinds: Set<PaEventKind>?)

    func removeListener(_ listener: Listener)

    func ask(_ event: PaEvent, timeout: Duration) async throws -> PaEvent
}

extension PaRemoteEventBus: PaSettingsContextEventBus {}
