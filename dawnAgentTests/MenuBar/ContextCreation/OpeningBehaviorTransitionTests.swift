//
//  OpeningBehaviorTransitionTests.swift
//  dawn
//

import Testing
import libdawn
import libdawnUI

@testable import dawnAgent

@Suite("Context opening behavior transition")
struct OpeningBehaviorTransitionTests {
    @Test(
        "Maps each opening behavior to an activation policy",
        arguments: [
            (ContextOpeningBehavior.onlyOpen, WorkspaceActivationPolicy.merge),
            (.hideOthers, .hide),
            (.closeOthers, .close),
        ]
    )
    func mapsOpeningBehavior(
        _ pair: (
            ContextOpeningBehavior,
            WorkspaceActivationPolicy
        )
    ) {
        #expect(pair.0.activationPolicy == pair.1)
        #expect(
            pair.0.transition
                == WorkspaceTransition(activationPolicy: pair.1)
        )
    }
}
