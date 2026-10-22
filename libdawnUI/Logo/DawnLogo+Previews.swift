// NEEDS REVIEW — PIN-132 (sidebar design): changed in this issue, pending organization review.
//
//  DawnLogo+Previews.swift
//  dawn
//

#if DEBUG

import SwiftUI

#Preview("DAWN Logo") {
    HStack(alignment: .bottom, spacing: 28) {
        ForEach(DawnLogo.Variant.allCases, id: \.self) { variant in
            VStack(spacing: 12) {
                DawnLogo(variant: variant)

                Text(logoVariantTitle(variant))
                    .font(DawnTextStyle.sidebarMeta)
                    .foregroundStyle(DawnColors.sidebarSecondaryForeground)
            }
            .frame(maxWidth: .infinity)
        }
    }
    .padding(28)
    .frame(width: 520)
    .background(DawnColors.primaryBackground)
}

private func logoVariantTitle(_ variant: DawnLogo.Variant) -> String {
    switch variant {
    case .symbol:
        "Symbol"
    case .wordmark:
        "Wordmark"
    case .stacked:
        "Stacked"
    }
}

#endif
