//
//  MenuBarModalPresentationState.swift
//  dawn
//
//  Created by Rafael Venetikides on 29/10/26.
//

import Foundation

@MainActor
final class MenuBarModalPresentationState {
    enum Presentation: Hashable {
        case contextListError
        case deleteConfirmation
        case contextCreationError
        case applicationImporter
    }

    private var activePresentations = Set<Presentation>()

    var isPresentingModal: Bool {
        activePresentations.isEmpty == false
    }

    func setPresented(_ isPresented: Bool, for presentation: Presentation) {
        if isPresented {
            activePresentations.insert(presentation)
        } else {
            activePresentations.remove(presentation)
        }
    }
}
