//
//  DawnZainOpticalAlignment.swift
//  dawn
//

import SwiftUI

public extension DawnTextStyle {
    /// Zain sits high in its em-box; a small top inset optically centers glyphs.
    static let zainOpticalTopPadding: CGFloat = 2
}

public struct DawnZainOpticalAlignment: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content.padding(.top, DawnTextStyle.zainOpticalTopPadding)
    }
}

public extension View {
    /// Optically centers Zain text that otherwise reads as vertically high.
    func dawnZainOpticalAlignment() -> some View {
        modifier(DawnZainOpticalAlignment())
    }

    @ViewBuilder
    func dawnZainOpticalAlignment(enabled: Bool) -> some View {
        if enabled {
            dawnZainOpticalAlignment()
        } else {
            self
        }
    }
}
