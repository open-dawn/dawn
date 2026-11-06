//
//  OpeningBehaviorTransitionTests.swift
//  dawn
//

import Testing
import libdawn
import libdawnUI

@Suite("Context creation activation policy")
struct OpeningBehaviorTransitionTests {
    @Test("Creation request carries the selected activation policy")
    func creationRequestCarriesActivationPolicy() {
        let request = ContextCreationRequest(
            name: "Focus",
            symbolName: "target",
            applications: [],
            activationPolicy: .merge
        )

        #expect(request.activationPolicy == .merge)
        #expect(
            request.transition
                == WorkspaceTransition(activationPolicy: .merge)
        )
    }
}
