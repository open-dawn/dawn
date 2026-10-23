//
//  DButtonStyle.swift
//  dawn
//
//  Created by Longhi on 20/10/26.
//

import SwiftUI

public enum DButtonStyle: CaseIterable {
    case primary
    case secondary
    case danger
    case warning
    case link
    case linkSecondary
    case plain
    case icon
    case compactIcon
    case compactLink

    var fgStyle: Color {
        switch self {
        case .primary: return DawnColors.secondaryBackground
        case .secondary: return DawnColors.primaryForeground
        case .danger: return DawnColors.dangerForeground
        case .warning: return DawnColors.warningForeground
        case .link: return DawnColors.primaryForeground
        case .linkSecondary: return DawnColors.secondaryForeground
        case .plain, .icon, .compactIcon, .compactLink: return DawnColors.primaryForeground
        }
    }

    var bgStyle: Color {
        switch self {
        case .primary: return DawnColors.primaryForeground
        case .secondary: return DawnColors.secondaryBackground
        case .danger: return DawnColors.dangerBackground
        case .warning: return DawnColors.warningBackground
        case .link: return .clear
        case .linkSecondary: return .clear
        case .plain, .icon, .compactIcon, .compactLink: return .clear
        }
    }

    var spacing: CGFloat {
        switch self {
        case .primary: return 8
        case .secondary: return 8
        case .danger: return 8
        case .warning: return 8
        case .link: return 8
        case .linkSecondary: return 8
        case .plain: return 8
        case .icon, .compactIcon: return 0
        case .compactLink: return 4
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .primary: return 12
        case .secondary: return 12
        case .danger: return 12
        case .warning: return 12
        case .link: return 6
        case .linkSecondary: return 0
        case .icon: return 4
        case .compactIcon: return 2
        case .plain, .compactLink: return 0
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .primary: return 16
        case .secondary: return 16
        case .danger: return 16
        case .warning: return 16
        case .link: return 0
        case .linkSecondary: return 0
        case .icon: return 4
        case .compactIcon: return 2
        case .plain, .compactLink: return 0
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .primary: return 8
        case .secondary: return 8
        case .danger: return 8
        case .warning: return 8
        case .link: return 8
        case .linkSecondary: return 8
        case .plain, .compactLink: return 0
        case .icon, .compactIcon: return 4
        }
    }

    var underlined: Bool {
        switch self {
        case .primary: return false
        case .secondary: return false
        case .danger: return false
        case .warning: return false
        case .link: return true
        case .linkSecondary: return true
        case .plain: return false
        case .icon: return false
        case .compactIcon: return false
        case .compactLink: return true
        }
    }

    var labelFont: Font {
        switch self {
        case .primary: return DawnTextStyle.buttonLabel
        case .secondary: return DawnTextStyle.buttonLabel
        case .danger: return DawnTextStyle.buttonLabel
        case .warning: return DawnTextStyle.buttonLabel
        case .link: return DawnTextStyle.buttonLabel
        case .linkSecondary: return DawnTextStyle.buttonLabel
        case .plain: return DawnTextStyle.body
        case .icon: return DawnTextStyle.actionIcon
        case .compactIcon: return DawnTextStyle.buttonIcon
        case .compactLink: return DawnTextStyle.linkLabel
        }
    }

    var iconFont: Font {
        switch self {
        case .primary: return DawnTextStyle.buttonIcon
        case .secondary: return DawnTextStyle.buttonIcon
        case .danger: return DawnTextStyle.buttonIcon
        case .warning: return DawnTextStyle.buttonIcon
        case .link: return DawnTextStyle.buttonIcon
        case .linkSecondary: return DawnTextStyle.buttonIcon
        case .plain: return DawnTextStyle.buttonIcon
        case .icon: return DawnTextStyle.actionIcon
        case .compactLink: return DawnTextStyle.buttonIcon
        case .compactIcon: return DawnTextStyle.actionIcon
        }
    }

    var lineLimit: Int? {
        switch self {
        case .primary: return 1
        case .secondary: return 1
        case .danger: return 1
        case .warning: return 1
        case .link: return 1
        case .linkSecondary: return 1
        case .plain: return nil
        case .icon: return 1
        case .compactIcon: return 1
        case .compactLink: return 1
        }
    }
}
