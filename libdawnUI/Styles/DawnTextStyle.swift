//
//  DawnTextStyle.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/10/26.
//

import SwiftUI

public enum DawnTextStyle {
    // MARK: - Context Cards

    public static let contextTitle: Font = .system(size: 12, weight: .bold)
    public static let contextMetadata: Font = .system(size: 9, weight: .regular)

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
}
