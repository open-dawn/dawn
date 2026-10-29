//
//  MenuBarPresentationStateTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 29/10/26.
//

import Testing

@testable import dawnAgent

@MainActor
@Suite("Menu bar modal presentation state")
struct MenuBarModalPresentationStateTests {
    typealias Presentation =
        MenuBarModalPresentationState.Presentation

    @Test("Starts without an active presentation")
    func startsEmpty() {
        let sut = MenuBarModalPresentationState()

        #expect(sut.isPresentingModal == false)
    }

    @Test(
        "Tracks every presentation type",
        arguments: [
            Presentation.contextListError,
            Presentation.deleteConfirmation,
            Presentation.contextCreationError,
            Presentation.applicationImporter,
        ]
    )
    func tracksPresentation(
        _ presentation: Presentation
    ) {
        let sut = MenuBarModalPresentationState()

        sut.setPresented(
            true,
            for: presentation
        )

        #expect(sut.isPresentingModal)

        sut.setPresented(
            false,
            for: presentation
        )

        #expect(sut.isPresentingModal == false)
    }

    @Test("Remains active until every presentation is dismissed")
    func tracksOverlappingPresentations() {
        let sut = MenuBarModalPresentationState()

        sut.setPresented(
            true,
            for: .contextListError
        )

        sut.setPresented(
            true,
            for: .applicationImporter
        )

        sut.setPresented(
            false,
            for: .contextListError
        )

        #expect(sut.isPresentingModal)

        sut.setPresented(
            false,
            for: .applicationImporter
        )

        #expect(sut.isPresentingModal == false)
    }

    @Test("Repeated presentation updates are idempotent")
    func repeatedUpdatesAreIdempotent() {
        let sut = MenuBarModalPresentationState()

        sut.setPresented(
            true,
            for: .deleteConfirmation
        )

        sut.setPresented(
            true,
            for: .deleteConfirmation
        )

        #expect(sut.isPresentingModal)

        sut.setPresented(
            false,
            for: .deleteConfirmation
        )

        sut.setPresented(
            false,
            for: .deleteConfirmation
        )

        #expect(sut.isPresentingModal == false)
    }
}
