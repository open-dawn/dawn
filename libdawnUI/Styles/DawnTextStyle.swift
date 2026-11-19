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

    public static let contextTitle: Font = DawnFont.zain(.bold, size: 18, relativeTo: .title)
    public static let contextMetadata: Font = DawnFont.gabarito(size: 10, relativeTo: .body)

    public static let noWorkspaceTitle: Font = DawnFont.zain(.bold, size: 24, relativeTo: .title)
    public static let noWorkspaceBody: Font = DawnFont.gabarito(size: 16, relativeTo: .body)
    public static let noWorkspaceBodyEmphasis: Font = DawnFont.gabarito(.bold, size: 16, relativeTo: .body)

    // MARK: Branding

    public static let brandTitle: Font = DawnFont.zain(.regular, size: 24, relativeTo: .title)
    public static let compactBrandTitle: Font = .system(size: 20)

    // MARK: Screen hierarchy

    public static let screenTitle: Font = .system(size: 21, weight: .bold)
    public static let compactScreenTitle: Font = .system(size: 18, weight: .bold)
    public static let body: Font = .system(size: 14)
    public static let fieldLabel: Font = .system(size: 14, weight: .light)
    public static let sectionLabel: Font = DawnFont.zain(.bold, size: 22, relativeTo: .title)
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

    public static let sidebarTextSize: CGFloat = 12
    public static let sidebarMetaSize: CGFloat = 8

    public static let sidebarLogo: Font = DawnFont.gabarito(size: sidebarTextSize, relativeTo: .body)
    public static let sidebarLogoSymbol: Font = .system(size: sidebarTextSize, weight: .regular)

    public static let sidebarLogoStackedSymbol: Font = .system(size: 28, weight: .regular)
    public static let sidebarLogoStackedTitle: Font = DawnFont.gabarito(
        .medium,
        size: sidebarTextSize,
        relativeTo: .body
    )

    public static let sidebarAction: Font = DawnFont.gabarito(size: sidebarTextSize, relativeTo: .body)

    public static let sidebarSectionHeader: Font = DawnFont.zain(
        .regular,
        size: sidebarTextSize,
        relativeTo: .body
    )
    public static let sidebarRow: Font = DawnFont.gabarito(size: sidebarTextSize, relativeTo: .body)
    public static let sidebarIcon: Font = .system(size: 14, weight: .regular)
    public static let sidebarRowIcon: Font = .system(size: 20, weight: .regular)
    public static let sidebarBannerIcon: Font = .system(size: 24, weight: .regular)

    public static let sidebarFooter: Font = DawnFont.gabarito(size: sidebarTextSize, relativeTo: .body)
    public static let sidebarMeta: Font = DawnFont.gabarito(size: sidebarMetaSize, relativeTo: .caption2)

    public static let sidebarBannerTitle: Font = DawnFont.gabarito(
        .bold,
        size: sidebarTextSize,
        relativeTo: .body
    )
    public static let sidebarBannerBody: Font = DawnFont.gabarito(
        size: sidebarTextSize,
        relativeTo: .body
    )
    public static let sidebarWarning: Font = DawnFont.gabarito(
        .bold,
        size: sidebarTextSize,
        relativeTo: .body
    )
    public static let sidebarRestart: Font = DawnFont.zain(
        .bold,
        size: sidebarTextSize,
        relativeTo: .body
    )
    public static let sidebarChevron: Font = .system(size: 10, weight: .regular)

    // MARK: - Text Field

    public static let textFieldSecondaryIcon: Font = .system(size: 12, weight: .bold)
}
