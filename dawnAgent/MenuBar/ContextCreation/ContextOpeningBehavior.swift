//
//  ContextOpeningBehavior.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/10/26.
//

enum ContextOpeningBehavior: CaseIterable, Hashable, Identifiable {
    case onlyOpen
    case hideOthers
    case closeOthers

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .onlyOpen:
            "Only open"
        case .hideOthers:
            "Hide others"
        case .closeOthers:
            "Close others"
        }
    }

    var detail: String {
        switch self {
        case .onlyOpen:
            "Open this workspace's apps while keeping others apps open."
        case .hideOthers:
            "Hide other apps' windows and remove them from the Dock."
        case .closeOthers:
            "Close all other apps open on your Mac."
        }
    }
}
