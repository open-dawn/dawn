//
//  DawnTextStyle.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/10/26.
//

import SwiftUI

public enum DawnTextStyle {
    /// Canonical type scale (max 4 sizes): title / body / secondary / meta.
    public static let titleSize: CGFloat = 24
    public static let bodySize: CGFloat = 16
    public static let secondarySize: CGFloat = 12
    public static let metaSize: CGFloat = 10

    public static let primary: Font = DawnFont.gabarito(size: bodySize, relativeTo: .body)
    public static let primaryBold: Font = DawnFont.gabarito(.bold, size: bodySize, relativeTo: .body)
    public static let secondary: Font = DawnFont.gabarito(size: bodySize, relativeTo: .body)

    // MARK: - Workspace Cards

    public static let workspaceTitle: Font = DawnFont.zain(.bold, size: bodySize, relativeTo: .title)
    public static let workspaceMetadata: Font = DawnFont.gabarito(size: metaSize, relativeTo: .body)

    public static let noWorkspaceTitle: Font = DawnFont.zain(.bold, size: titleSize, relativeTo: .title)
    public static let noWorkspaceBody: Font = DawnFont.gabarito(size: bodySize, relativeTo: .body)
    public static let noWorkspaceBodyEmphasis: Font = DawnFont.gabarito(.bold, size: bodySize, relativeTo: .body)

    // MARK: Branding
    public static let brandTitle: Font = DawnFont.zain(.regular, size: titleSize, relativeTo: .title)
    public static let compactBrandTitle: Font = .system(size: titleSize)

    // MARK: Screen hierarchy
    public static let screenTitle: Font = DawnFont.zain(.bold, size: titleSize, relativeTo: .title)
    public static let compactScreenTitle: Font = .system(size: bodySize, weight: .bold)
    public static let body: Font = DawnFont.gabarito(size: bodySize, relativeTo: .body)
    public static let emphasizedBody: Font = DawnFont.gabarito(.bold, size: bodySize, relativeTo: .body)
    public static let confirmationTitle: Font = DawnFont.zain(.bold, size: titleSize, relativeTo: .title2)
    public static let confirmationWorkspaceTitle: Font = DawnFont.zain(.bold, size: bodySize, relativeTo: .headline)
    public static let confirmationAction: Font = DawnFont.gabarito(size: bodySize, relativeTo: .body)
    public static let fieldLabel: Font = .system(size: secondarySize, weight: .light)
    public static let sectionLabel: Font = DawnFont.zain(.bold, size: titleSize, relativeTo: .title)
    public static let settingsSectionTitle: Font = DawnFont.gabarito(
        .bold,
        size: bodySize,
        relativeTo: .body
    )
    public static let linkLabel: Font = .system(size: secondarySize, weight: .light)

    // MARK: - Workspace detail
    // Content panes (detail + settings) share body (16) for labels/fields.
    // Sidebar stays on secondary (12) for dense chrome.

    /// Detail pane title.
    public static let detailTitle: Font = DawnFont.zain(.bold, size: titleSize, relativeTo: .headline)
    /// Section labels in the detail pane (same size as settings section titles).
    public static let detailSectionLabel: Font = DawnFont.gabarito(
        .bold,
        size: bodySize,
        relativeTo: .body
    )
    /// Field / chip body text in the detail pane (same size as settings body).
    public static let detailField: Font = DawnFont.gabarito(size: bodySize, relativeTo: .body)
    /// Empty / supporting copy under detail controls.
    public static let detailSupporting: Font = DawnFont.gabarito(size: secondarySize, relativeTo: .caption)
    /// Compact action label on the detail header Start button.
    public static let detailAction: Font = DawnFont.zain(.bold, size: metaSize, relativeTo: .caption2)

    // MARK: Options and supporting information

    public static let optionTitle: Font = .system(size: bodySize, weight: .light)
    public static let caption: Font = DawnFont.gabarito(size: secondarySize, relativeTo: .caption)
    public static let captionBold: Font = DawnFont.gabarito(.bold, size: secondarySize, relativeTo: .caption)
    public static let secondaryCaption: Font = DawnFont.gabarito(size: secondarySize, relativeTo: .caption)

    // MARK: Icons presented as typography

    public static let actionIcon: Font = .system(size: bodySize, weight: .light)
    public static let selectionIcon: Font = .system(size: bodySize)
    public static let symbolPickerIcon: Font = .system(size: titleSize)

    // MARK: - Button

    public static let buttonLabel: Font = .system(size: bodySize, weight: .semibold)
    public static let buttonIcon: Font = .system(size: secondarySize, weight: .bold)

    public static let detailButton: Font = DawnFont.zain(.bold, size: bodySize, relativeTo: .body)

    public static let activationPolicyTitle: Font = DawnFont.gabarito(size: bodySize, relativeTo: .body)

    public static let activationPolicyDescription: Font = DawnFont.gabarito(
        size: secondarySize,
        relativeTo: .caption
    )

    public static let activationPolicyIcon: Font = .system(size: bodySize, weight: .medium)

    // MARK: - Sidebar

    public static let sidebarTextSize: CGFloat = secondarySize
    public static let sidebarMetaSize: CGFloat = metaSize

    public static let sidebarLogo: Font = DawnFont.gabarito(size: sidebarTextSize, relativeTo: .body)
    public static let sidebarLogoSymbol: Font = .system(size: sidebarTextSize, weight: .regular)

    public static let sidebarLogoStackedSymbol: Font = .system(size: titleSize, weight: .regular)
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
    public static let sidebarIcon: Font = .system(size: secondarySize, weight: .regular)
    public static let sidebarRowIcon: Font = .system(size: bodySize, weight: .regular)
    public static let sidebarBannerIcon: Font = .system(size: titleSize, weight: .regular)

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
    public static let sidebarChevron: Font = .system(size: metaSize, weight: .regular)

    // MARK: - Text Field

    public static let textFieldSecondaryIcon: Font = .system(size: secondarySize, weight: .bold)
}
