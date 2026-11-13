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

    public static let inputBackground = Color(.inputBackground)

    // MARK: Selection

    public static let selectionBackground = Color(.selectionBackground)

    public static let selectionForeground = Color(.selectionForeground)

    public static let contextCardBackground = Color(.contextCardBackground)
    public static let contextCardHoveredBackground = Color(.contextCardHoveredBackground)
    public static let contextCardBorder = Color(.contextCardBorder)
    public static let contextCardHoveredBorder = Color(.contextCardHoveredBorder)

    public static let primaryBackground = Color(.primaryBackground) // #1f1f1f
    public static let secondaryBackground = Color(.secondaryBackground)

    public static let primaryForeground = Color(.primaryForeground)
    public static let secondaryForeground = Color(.secondaryForeground)

    public static let dangerBackground = Color.red.opacity(0.15)
    public static let dangerForeground = Color.red

    public static let successBackground = Color.green.opacity(0.15)
    public static let successForeground = Color.green

    public static let warningBackground = Color.yellow.opacity(0.15)
    public static let warningForeground = Color.yellow

    // MARK: - Sidebar colors

    public static let sidebarBackground = Color(.sidebarBackground)
    public static let sidebarRowSelected = Color(.sidebarRowSelected)
    public static let sidebarForeground = Color(.sidebarForeground)

    public static let sidebarIcon = Color(.sidebarIcon)
    public static let sidebarSecondaryForeground = Color(.sidebarSecondaryForeground)
    public static let sidebarTertiaryForeground = Color(.sidebarTertiaryForeground)
    public static let sidebarActive = Color(.sidebarActive)

    public static let sidebarWarningBackground = Color(.sidebarWarningBackground).opacity(0.15)
    public static let sidebarWarningForeground = Color(.sidebarWarningForeground)

    public static let textFieldInset = Color(.textFieldInset)
}
