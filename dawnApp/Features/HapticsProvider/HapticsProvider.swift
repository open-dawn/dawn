//
//  HapticsProvider.swift
//  pineapplewm
//
//  Created by Longhi on 29/09/26.
//

enum HapticPattern: Sendable {
    case weakClick
    case strongClick
    case buzz
    case lightTap
    case mediumTap
    case strongTap
    case softThud
    case strongThud
}

protocol HapticsProvider: Sendable {
    func perform(_ pattern: HapticPattern)
}
