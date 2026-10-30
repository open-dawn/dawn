//
//  MenuBarVisibilityStoring.swift
//  dawn
//
//  Created by Rafael Venetikides on 28/10/26.
//

import Foundation

protocol MenuBarVisibilityStoring: Sendable {
    func menuBarIsVisible() async -> Bool

    func setMenuBarVisible(_ isVisible: Bool) async throws
}
