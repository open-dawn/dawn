// NEEDS REVIEW — PIN-132 (sidebar design): changed in this issue, pending organization review.
//
//  DawnColors.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/10/26.
//

import SwiftUI

public enum DawnColors {
    public static let contextCardBackground = Color.black.opacity(0.25)

    public static let contextCardHoveredBackground = Color.black.opacity(0.34)

    public static let contextCardBorder = Color.white.opacity(0.04)

    public static let contextCardHoveredBorder = Color.white.opacity(0.10)

    public static let primaryBackground = Color(red: 0x1f/0xff, green: 0x1f/0xff, blue: 0x1f/0xff) // #1f1f1f

    public static let secondaryBackground = Color(red: 0x27/0xff, green: 0x27/0xff, blue: 0x27/0xff) // #272727

    public static let primaryForeground = Color(red: 0xff/0xff, green: 0xff/0xff, blue: 0xff/0xff) // #ffffff

    public static let dangerBackground = Color.red.opacity(0.3)

    public static let dangerForeground = Color.red

    public static let warningBackground = Color.yellow.opacity(0.3)

    public static let warningForeground = Color.yellow

    public static let sidebarBackground = Color(
        red: 0x1f / 0xff,
        green: 0x1f / 0xff,
        blue: 0x1f / 0xff
    ).opacity(0.5)

    public static let sidebarRowSelected = Color.black.opacity(0.25)

    public static let sidebarForeground = Color(
        red: 0xf1 / 0xff,
        green: 0xf1 / 0xff,
        blue: 0xf1 / 0xff
    )

    public static let sidebarIcon = Color.white.opacity(0.75)

    public static let sidebarSecondaryForeground = Color.white.opacity(0.55)

    public static let sidebarTertiaryForeground = Color.white.opacity(0.25)

    public static let sidebarActive = Color(
        red: 0x48 / 0xff,
        green: 0xbc / 0xff,
        blue: 0x59 / 0xff
    )

    public static let sidebarWarningBackground = Color(
        red: 145.0 / 255.0,
        green: 108.0 / 255.0,
        blue: 8.0 / 255.0
    ).opacity(0.15)

    public static let sidebarWarningForeground = Color(
        red: 0xf3 / 0xff,
        green: 0xbc / 0xff,
        blue: 0x28 / 0xff
    )

    public static let sidebarSearchField = Color.black.opacity(0.25)
}
