//
//  DawnSymbol.swift
//  dawn
//

import AppKit
import SwiftUI

public enum DawnSymbol {
    public static var nsImage: NSImage? {
        DawnUIBundle.bundle.image(forResource: "DawnSymbol")
    }

    public static func image(height: CGFloat) -> some View {
        Image("DawnSymbol", bundle: DawnUIBundle.bundle)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

enum DawnUIBundle {
    static let bundle = Bundle(for: DawnUIBundleToken.self)
}

private final class DawnUIBundleToken: NSObject {}
