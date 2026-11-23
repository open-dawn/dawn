//
//  LogoComplete.swift
//  dawn
//

import AppKit
import SwiftUI

public enum LogoComplete {
    public static var nsImage: NSImage? {
        DawnUIBundle.bundle.image(forResource: "logoComplete")
    }

    public static func image(height: CGFloat) -> some View {
        Image("logoComplete", bundle: DawnUIBundle.bundle)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityHidden(true)
    }
}
