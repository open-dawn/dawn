//
//  DawnSymbol.swift
//  dawn
//

import AppKit
import SwiftUI

public enum DawnSymbol {
    public static var nsImage: NSImage? {
        nsImage(isActive: true)
    }

    public static var deactivatedNSImage: NSImage? {
        nsImage(isActive: false)
    }

    public static func nsImage(isActive: Bool) -> NSImage? {
        let resourceName = isActive ? "DawnSymbol" : "DawnSymbolDesactivated"
        return DawnUIBundle.bundle.image(forResource: resourceName)
    }

    public static func image(height: CGFloat) -> some View {
        image(height: height, isActive: true)
    }

    public static func image(height: CGFloat, isActive: Bool) -> some View {
        Image(
            isActive ? "DawnSymbol" : "DawnSymbolDesactivated",
            bundle: DawnUIBundle.bundle
        )
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
