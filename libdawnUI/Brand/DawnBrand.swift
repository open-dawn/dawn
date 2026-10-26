//
//  DawnBrand.swift
//  dawn
//
//  Created by Rafael Venetikides on 23/10/26.
//

import SwiftUI

public struct DawnBrand: View {
    public enum Style {
        case proeminent
        case compact

        var font: Font {
            switch self {
            case .proeminent:
                DawnTextStyle.brandTitle
            case .compact:
                DawnTextStyle.compactBrandTitle
            }
        }

        var spacing: CGFloat {
            switch self {
            case .proeminent:
                5
            case .compact:
                4
            }
        }
    }

    private let style: Style

    public init(style: Style = .proeminent) {
        self.style = style
    }

    public var body: some View {
        HStack(spacing: style.spacing) {
            Image(systemName: "sun.horizon")
                .accessibilityHidden(true)

            Text("dawn")
        }
        .font(style.font)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("DAWN")
    }
}
