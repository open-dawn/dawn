//
//  DuskMenuBarBackground.swift
//  dawn
//
//  Created by Rafael Venetikides on 15/11/26.
//

import SwiftUI

public struct DuskMenuBarBackground: View {
    public init() {}

    public var body: some View {
        Image(
            "DuskMenuBarBackground",
            bundle: DawnUIBundle.bundle
        )
        .renderingMode(.original)
        .resizable()
        .scaledToFit()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
