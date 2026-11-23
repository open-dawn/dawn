//
//  DuskSleepy.swift
//  dawn
//
//  Created by Rafael Venetikides on 16/11/26.
//

import SwiftUI

public enum DuskSleepy {
    public static var nsImage: NSImage? {
        DawnUIBundle.bundle.image(forResource: "DuskSleepy")
    }

    public static func image(height: CGFloat) -> some View {
        Image("DuskSleepy", bundle: DawnUIBundle.bundle)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityHidden(true)
    }
}
