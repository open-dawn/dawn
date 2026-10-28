//
//  DawnColors.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/10/26.
//

import SwiftUI

public enum DawnColors {
    // MARK: Text and icons

    public static let menuItemSecondaryForeground = Color.secondary

    // MARK: Inputs

    public static let inputBackground = Color.black.opacity(0.25)

    // MARK: Selection

    public static let selectionBackground = Color.white

    public static let selectionForeground = Color.black

    public static let contextCardBackground = Color.black.opacity(0.25)
    public static let contextCardHoveredBackground = Color.black.opacity(0.34)
    public static let contextCardBorder = Color.white.opacity(0.04)
    public static let contextCardHoveredBorder = Color.white.opacity(0.10)

    public static let primaryBackground = Color(red: 0x1F / 0xFF, green: 0x1F / 0xFF, blue: 0x1F / 0xFF) // #1f1f1f
    public static let secondaryBackground = Color(red: 0x27 / 0xFF, green: 0x27 / 0xFF, blue: 0x27 / 0xFF) // #272727

    public static let primaryForeground = Color(red: 0xFF / 0xFF, green: 0xFF / 0xFF, blue: 0xFF / 0xFF) // #ffffff
    public static let secondaryForeground = Color(red: 0x70 / 0xFF, green: 0x70 / 0xFF, blue: 0x70 / 0xFF) // #707070

    public static let dangerBackground = Color.red.opacity(0.15)
    public static let dangerForeground = Color.red

    public static let successBackground = Color.green.opacity(0.15)
    public static let successForeground = Color.green

    public static let warningBackground = Color.yellow.opacity(0.15)
    public static let warningForeground = Color.yellow

    // MARK: - Sidebar colors

    public static let sidebarBackground = Color(
        red: 0x1F / 0xFF,
        green: 0x1F / 0xFF,
        blue: 0x1F / 0xFF
    ).opacity(0.5)

    public static let sidebarRowSelected = Color.black.opacity(0.25)
    public static let sidebarForeground = Color(
        red: 0xF1 / 0xFF,
        green: 0xF1 / 0xFF,
        blue: 0xF1 / 0xFF
    )

    public static let sidebarIcon = Color.white.opacity(0.75)
    public static let sidebarSecondaryForeground = Color.white.opacity(0.55)
    public static let sidebarTertiaryForeground = Color.white.opacity(0.25)
    public static let sidebarActive = Color(
        red: 0x48 / 0xFF,
        green: 0xBC / 0xFF,
        blue: 0x59 / 0xFF
    )

    public static let sidebarWarningBackground = Color(
        red: 145.0 / 255.0,
        green: 108.0 / 255.0,
        blue: 8.0 / 255.0
    ).opacity(0.15)
    public static let sidebarWarningForeground = Color(
        red: 0xF3 / 0xFF,
        green: 0xBC / 0xFF,
        blue: 0x28 / 0xFF
    )

    public static let textFieldInset = Color.black.opacity(0.25)
}
