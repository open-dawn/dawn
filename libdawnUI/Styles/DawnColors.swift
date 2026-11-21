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

    public static let emphasizedBody = Color(.emphasizedBody)

    // MARK: Inputs

    public static let inputBackground = Color(.inputBackground)

    public static let primaryButtonBackground = Color(.primaryButtonBackground)
    public static let primaryButtonBackgroundDisabled = Color(.primaryButtonBackgroundDisabled)

    public static let activationPolicyBackground = Color(.activationPolicyBackground)

    public static let activationPolicyTitle = Color(.activationPolicyTitle)

    public static let activationPolicyDescription = Color(.activationPolicyDescription)

    public static let activationPolicySelectedBackground = Color(.activationPolicySelectedBackground)

    public static let activationPolicySelectedTitle = Color(.activationPolicySelectedTitle)

    public static let activationPolicySelectedDescription = Color(.activationPolicySelectedDescription)

    public static let detailForeground = Color(.detailForeground)

    // MARK: Selection

    public static let selectionBackground = Color(.selectionBackground)

    public static let selectionForeground = Color(.selectionForeground)

    public static let contextCardBackground = Color(.contextCardBackground)
    public static let contextCardHoveredBackground = Color(.contextCardHoveredBackground)

    public static let selectedContextCardBackground = Color(.selectedContextCardBackground)
    public static let selectedContextCardHoveredBackground = Color(.selectedContextCardHoveredBackground)

    public static let contextCardBorder = Color(.contextCardBorder)
    public static let contextCardHoveredBorder = Color(.contextCardHoveredBorder)

    public static let contextCardContent = Color(.contextCardContent)
    public static let contextCardContentActive = Color(.contextCardContentActive)

    public static let primaryBackground = Color(.primaryBackground) // #FDF6EE / #212121
    public static let secondaryBackground = Color(.secondaryBackground)

    public static let primaryForeground = Color(.primaryForeground) // #272727 / #FFFFFF
    public static let secondaryForeground = Color(.secondaryForeground) // #636363

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
