//
//  ContextCreationStepHeader.swift
//  dawn
//
//  Created by Rafael Venetikides on 23/10/26.
//

import SwiftUI
import libdawnUI

struct ContextCreationStepHeader: View {
    enum Style {
        case standard
        case compact

        var titleFont: Font {
            switch self {
            case .standard:
                DawnTextStyle.screenTitle
            case .compact:
                DawnTextStyle.compactScreenTitle
            }
        }
    }

    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let style: Style

    init(title: LocalizedStringKey, subtitle: LocalizedStringKey, style: Style = .standard) {
        self.title = title
        self.subtitle = subtitle
        self.style = style
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(style.titleFont)

            Text(subtitle)
                .font(DawnTextStyle.body)
                .foregroundStyle(DawnColors.menuItemSecondaryForeground)
        }
        .multilineTextAlignment(.center)
    }
}
