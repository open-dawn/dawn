//
//  DawnTextStyle.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/10/26.
//

import SwiftUI

public enum DawnTextStyle {
    public static let primary: Font = .system(size: 16, weight: .regular)
    public static let secondary: Font = .system(size: 16, weight: .regular)

    // MARK: - Context Cards

    public static let contextTitle: Font = .system(size: 12, weight: .bold)
    public static let contextMetadata: Font = .system(size: 9, weight: .regular)

    // MARK: Branding
    public static let brandTitle: Font = .system(size: 24)
    public static let compactBrandTitle: Font = .system(size: 20)

    // MARK: Screen hierarchy
    public static let screenTitle: Font = .system(size: 21, weight: .bold)
    public static let compactScreenTitle: Font = .system(size: 18, weight: .bold)
    public static let body: Font = .system(size: 14)
    public static let fieldLabel: Font = .system(size: 14, weight: .light)
    public static let sectionLabel: Font = .system(size: 12, weight: .light)
    public static let linkLabel: Font = .system(size: 12, weight: .light)

    // MARK: Options and supporting information
    public static let optionTitle: Font = .system(size: 18, weight: .light)
    public static let caption: Font = .system(size: 11)
    public static let secondaryCaption: Font = .system(size: 11, weight: .light)

    // MARK: Icons presented as typography
    public static let actionIcon: Font = .system(size: 20, weight: .light)
    public static let selectionIcon: Font = .system(size: 18)
    public static let symbolPickerIcon: Font = .system(size: 25)

    // MARK: - Button

    public static let buttonLabel: Font = .system(size: 16, weight: .semibold)
    public static let buttonIcon: Font = .system(size: 14, weight: .bold)

    // MARK: - Sidebar

    public static let sidebarLogo: Font = .system(size: 13, weight: .regular)
    public static let sidebarLogoSymbol: Font = .system(size: 14, weight: .regular)

    public static let sidebarLogoStackedSymbol: Font = .system(size: 28, weight: .regular)
    public static let sidebarLogoStackedTitle: Font = .system(size: 15, weight: .medium)

    public static let sidebarAction: Font = .system(size: 13, weight: .regular)

    public static let sidebarSectionHeader: Font = .system(size: 11, weight: .regular)
    public static let sidebarRow: Font = .system(size: 13, weight: .regular)
    public static let sidebarIcon: Font = .system(size: 16, weight: .regular)

    public static let sidebarFooter: Font = .system(size: 13, weight: .regular)
    public static let sidebarMeta: Font = .system(size: 12, weight: .regular)

    public static let sidebarWarning: Font = .system(size: 11, weight: .bold)
    public static let sidebarChevron: Font = .system(size: 10, weight: .semibold)

    // MARK: - Text Field

    public static let textFieldSecondaryIcon: Font = .system(size: 12, weight: .bold)
}
