//
//  DawnFont.swift
//  dawn
//
//  Created by Rafael Venetikides on 15/11/26.
//

import CoreText
import Foundation
import SwiftUI

enum DawnFont {
    enum GabaritoWeight: String, Sendable {
        case regular = "Gabarito-Regular"
        case medium = "Gabarito-Medium"
        case semibold = "Gabarito-SemiBold"
        case bold = "Gabarito-Bold"
        case extraBold = "Gabarito-ExtraBold"
        case black = "Gabarito-Black"
    }

    enum ZainWeight: String, Sendable {
        case extraLight = "Zain-ExtraLight"
        case light = "Zain-Light"
        case regular = "Zain-Regular"
        case bold = "Zain-Bold"
        case extraBold = "Zain-ExtraBold"
        case black = "Zain-Black"
        case italic = "Zain-Italic"
        case lightItalic = "Zain-LightItalic"
    }

    private enum Resource: String, CaseIterable {
        case gabarito = "Gabarito-VariableFont_wght"
        case zainExtraLight = "Zain-ExtraLight"
        case zainLight = "Zain-Light"
        case zainRegular = "Zain-Regular"
        case zainBold = "Zain-Bold"
        case zainExtraBold = "Zain-ExtraBold"
        case zainBlack = "Zain-Black"
        case zainItalic = "Zain-Italic"
        case zainLightItalic = "Zain-LightItalic"
    }

    private final class BundleToken {}

    private static let registration: Void = {
        let bundle = Bundle(for: BundleToken.self)

        for resource in Resource.allCases {
            guard
                let url = bundle.url(
                    forResource: resource.rawValue,
                    withExtension: "ttf"
                )
            else {
                assertionFailure(
                    "Missing bundled font: \(resource.rawValue).ttf"
                )
                continue
            }

            var unmanagedError: Unmanaged<CFError>?

            let wasRegistered = CTFontManagerRegisterFontsForURL(
                url as CFURL,
                .process,
                &unmanagedError
            )

            guard !wasRegistered else {
                continue
            }

            let error = unmanagedError?.takeRetainedValue()

            if let error,
                CFErrorGetCode(error)
                    == CTFontManagerError.alreadyRegistered.rawValue
            {
                continue
            }

            assertionFailure(
                "Unable to register \(resource.rawValue): "
                    + "\(String(describing: error))"
            )
        }
    }()

    static func gabarito(
        _ weight: GabaritoWeight = .regular,
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        custom(
            named: weight.rawValue,
            size: size,
            relativeTo: textStyle
        )
    }

    static func zain(
        _ style: ZainWeight = .regular,
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        custom(
            named: style.rawValue,
            size: size,
            relativeTo: textStyle
        )
    }

    private static func custom(
        named postScriptName: String,
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        _ = registration

        return .custom(
            postScriptName,
            size: size,
            relativeTo: textStyle
        )
    }
}
