//
//  DButtonStyle.swift
//  dawn
//
//  Created by Longhi on 20/10/26.
//

import SwiftUI

enum DButtonStyle: CaseIterable {
    case primary
    case secondary
    case danger
    case warning
    case link

    var fgStyle: Color {
        switch self {
        case .primary: return DawnColors.secondaryBackground
        case .secondary: return DawnColors.primaryForeground
        case .danger: return DawnColors.dangerForeground
        case .warning: return DawnColors.warningForeground
        case .link: return DawnColors.primaryForeground
        }
    }

    var bgStyle: Color {
        switch self {
        case .primary: return DawnColors.primaryForeground
        case .secondary: return DawnColors.secondaryBackground
        case .danger: return DawnColors.dangerBackground
        case .warning: return DawnColors.warningBackground
        case .link: return .clear
        }
    }

    var spacing: CGFloat {
        switch self {
        case .primary: return 8
        case .secondary: return 8
        case .danger: return 8
        case .warning: return 8
        case .link: return 8
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .primary: return 12
        case .secondary: return 12
        case .danger: return 12
        case .warning: return 12
        case .link: return 6
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .primary: return 16
        case .secondary: return 16
        case .danger: return 16
        case .warning: return 16
        case .link: return 0
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .primary: return 8
        case .secondary: return 8
        case .danger: return 8
        case .warning: return 8
        case .link: return 8
        }
    }

    var underlined: Bool {
        switch self {
        case .primary: return false
        case .secondary: return false
        case .danger: return false
        case .warning: return false
        case .link: return true
        }
    }

    var labelFont: Font {
        switch self {
        case .primary: return DawnTextStyle.buttonLabel
        case .secondary: return DawnTextStyle.buttonLabel
        case .danger: return DawnTextStyle.buttonLabel
        case .warning: return DawnTextStyle.buttonLabel
        case .link: return DawnTextStyle.buttonLabel
        }
    }

    var iconFont: Font {
        switch self {
        case .primary: return DawnTextStyle.buttonIcon
        case .secondary: return DawnTextStyle.buttonIcon
        case .danger: return DawnTextStyle.buttonIcon
        case .warning: return DawnTextStyle.buttonIcon
        case .link: return DawnTextStyle.buttonIcon
        }
    }
}
