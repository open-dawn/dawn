//
//  DawnLogo.swift
//  dawn
//

import SwiftUI

public struct DawnLogo: View {
    public enum Variant: CaseIterable, Hashable, Sendable {
        case symbol
        case wordmark
        case stacked
    }

    private let variant: Variant

    public init(variant: Variant = .wordmark) {
        self.variant = variant
    }

    public var body: some View {
        content
            // The logo is a fixed-size identity mark: never let a greedy
            // parent (stack, safe-area bar, toolbar) stretch it.
            .fixedSize(horizontal: true, vertical: true)
            .foregroundStyle(DawnColors.primaryForeground)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("DAWN")
    }

    @ViewBuilder
    private var content: some View {
        switch variant {
        case .symbol:
            symbol
                .font(DawnTextStyle.sidebarLogoSymbol)
        case .wordmark:
            wordmark
        case .stacked:
            stacked
        }
    }

    private var symbol: some View {
        Image(systemName: "sun.horizon")
            .accessibilityHidden(true)
    }

    private var wordmark: some View {
        HStack(spacing: 5) {
            symbol
                .font(DawnTextStyle.sidebarLogoSymbol)

            Text("dawn")
                .font(DawnTextStyle.sidebarLogo)
        }
    }

    private var stacked: some View {
        VStack(spacing: 6) {
            symbol
                .font(DawnTextStyle.sidebarLogoStackedSymbol)

            Text("dawn")
                .font(DawnTextStyle.sidebarLogoStackedTitle)
        }
    }
}
