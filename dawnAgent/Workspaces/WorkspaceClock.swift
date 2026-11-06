//
//  WorkspaceClock.swift
//  dawn
//
//  Created by Rafael Venetikides on 26/10/26.
//

import Foundation

@MainActor
protocol WorkspaceClock {
    var now: Date { get }
}

struct SystemWorkspaceClock: WorkspaceClock {
    var now: Date {
        Date()
    }
}
