//
//  DButton.swift
//  dawn
//
//  Created by Longhi on 20/10/26.
//

import SwiftUI

public struct DButton<Leading: View, Content: View, Trailing: View>: View {
    private let style: DButtonStyle
    private let action: () -> Void
    private let leading: Leading
    private let content: Content
    private let trailing: Trailing

    public init(
        style: DButtonStyle = .primary,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
        @ViewBuilder leading: () -> Leading = {EmptyView()},
        @ViewBuilder trailing: () -> Trailing = {EmptyView()}
    ) {
        self.style = style
        self.action = action
        self.leading = leading()
        self.content = content()
        self.trailing = trailing()
    }

    public var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: style.spacing) {
                if Leading.self != EmptyView.self {
                    leading
                        .font(style.iconFont)
                }

                content
                    .font(style.labelFont)

                if Trailing.self != EmptyView.self {
                    trailing
                        .font(style.iconFont)
                }
            }
            .padding(.vertical, style.verticalPadding)
            .padding(.horizontal, style.horizontalPadding)
            .lineLimit(style.lineLimit)
            .foregroundStyle(style.fgStyle)
            .underline(style.underlined, color: style.fgStyle)
            .background {
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(style.bgStyle)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
