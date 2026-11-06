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
            .fixedSize(horizontal: true, vertical: true)
            .foregroundStyle(DawnColors.primaryForeground)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("DAWN")
    }

    @ViewBuilder
    private var content: some View {
        switch variant {
        case .symbol:
            symbol(height: 12)
        case .wordmark:
            wordmark
        case .stacked:
            stacked
        }
    }

    private func symbol(height: CGFloat) -> some View {
        DawnSymbol.image(height: height)
    }

    private var wordmark: some View {
        HStack(spacing: 5) {
            symbol(height: 12)

            Text("dawn")
                .font(DawnTextStyle.sidebarLogo)
        }
    }

    private var stacked: some View {
        VStack(spacing: 6) {
            symbol(height: 26)

            Text("dawn")
                .font(DawnTextStyle.sidebarLogoStackedTitle)
        }
    }
}
