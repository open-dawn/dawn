//
//  DawnTextStyle.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/10/26.
//

import SwiftUI

public enum DawnTextStyle {
    public static let primary: Font = DawnFont.gabarito(size: 16, relativeTo: .body)
    public static let primaryBold: Font = DawnFont.gabarito(.bold, size: 16, relativeTo: .body)
    public static let secondary: Font = DawnFont.gabarito(size: 16, relativeTo: .body)

    // MARK: - Context Cards

    public static let contextTitle: Font = DawnFont.zain(.bold, size: 18, relativeTo: .title)
    public static let contextMetadata: Font = DawnFont.gabarito(size: 10, relativeTo: .body)

    public static let noWorkspaceTitle: Font = DawnFont.zain(.bold, size: 28, relativeTo: .title)
    public static let noWorkspaceBody: Font = DawnFont.gabarito(size: 16, relativeTo: .body)

    // MARK: Branding
    public static let brandTitle: Font = DawnFont.zain(.regular, size: 24, relativeTo: .title)
    public static let compactBrandTitle: Font = .system(size: 20)

    // MARK: Screen hierarchy
    public static let screenTitle: Font = DawnFont.zain(.bold, size: 28, relativeTo: .title)
    public static let compactScreenTitle: Font = .system(size: 18, weight: .bold)
    public static let body: Font = DawnFont.gabarito(size: 16, relativeTo: .body)
    public static let emphasizedBody: Font = DawnFont.gabarito(.bold, size: 16, relativeTo: .body)
    public static let confirmationTitle: Font = DawnFont.zain(.bold, size: 24, relativeTo: .title2)
    public static let confirmationWorkspaceTitle: Font = DawnFont.zain(.bold, size: 16, relativeTo: .headline)
    public static let confirmationAction: Font = DawnFont.gabarito(size: 16, relativeTo: .body)
    public static let fieldLabel: Font = .system(size: 14, weight: .light)
    public static let sectionLabel: Font = DawnFont.zain(.bold, size: 22, relativeTo: .title)
    public static let settingsSectionTitle: Font = DawnFont.gabarito(
        .bold,
        size: 16,
        relativeTo: .body
    )
    public static let linkLabel: Font = .system(size: 12, weight: .light)

    // MARK: - Context detail (Figma fixed sizes)

    /// Detail pane title (Figma: Zain Bold 16).
    public static let detailTitle: Font = DawnFont.zain(.bold, size: 16, relativeTo: .headline)
    /// Section labels in the detail pane (Figma: Gabarito Bold 12).
    public static let detailSectionLabel: Font = DawnFont.gabarito(.bold, size: 12, relativeTo: .caption)
    /// Field / chip body text in the detail pane (Figma: Gabarito Regular 12).
    public static let detailField: Font = DawnFont.gabarito(size: 12, relativeTo: .caption)
    /// Empty / supporting copy under detail controls (Figma: Gabarito Regular 12).
    public static let detailSupporting: Font = DawnFont.gabarito(size: 12, relativeTo: .caption)
    /// Compact action label on the detail header Start button (Figma: Zain Bold 10).
    public static let detailAction: Font = DawnFont.zain(.bold, size: 10, relativeTo: .caption2)

    // MARK: Options and supporting information
    public static let optionTitle: Font = .system(size: 18, weight: .light)
    public static let caption: Font = DawnFont.gabarito(size: 12, relativeTo: .caption)
    public static let captionBold: Font = DawnFont.gabarito(.bold, size: 12, relativeTo: .caption)
    public static let secondaryCaption: Font = DawnFont.gabarito(size: 12, relativeTo: .caption)

    // MARK: Icons presented as typography
    public static let actionIcon: Font = .system(size: 20, weight: .light)
    public static let selectionIcon: Font = .system(size: 18)
    public static let symbolPickerIcon: Font = .system(size: 25)

    // MARK: - Button

    public static let buttonLabel: Font = .system(size: 16, weight: .semibold)
    public static let buttonIcon: Font = .system(size: 14, weight: .bold)

    public static let activationPolicyTitle: Font = DawnFont.gabarito(size: 12, relativeTo: .caption)

    public static let activationPolicyDescription: Font = DawnFont.gabarito(size: 10, relativeTo: .caption2)

    public static let activationPolicyIcon: Font = .system(size: 16, weight: .medium)

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
