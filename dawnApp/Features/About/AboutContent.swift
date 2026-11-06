//
//  AboutContent.swift
//  dawn
//
//  Created by Longhi on 21/10/26.
//

import Foundation

struct AboutContent: Equatable {
    let ticket: BuildTicket
    let appVersion: String

    static func load(from bundle: Bundle = .main) throws -> AboutContent {
        guard let appVersion = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String,
              !appVersion.isEmpty
        else {
            throw AboutContentLoadingError.missingAppVersion
        }

        return AboutContent(
            ticket: .current,
            appVersion: appVersion
        )
    }

    static func loadRequired(
        from bundle: Bundle = .main
    ) -> AboutContent {
        do {
            return try load(from: bundle)
        } catch {
            fatalError("Failed to load About content: \(error)")
        }
    }
}

enum AboutContentLoadingError: LocalizedError {
    case missingAppVersion

    var errorDescription: String? {
        switch self {
        case .missingAppVersion:
            "CFBundleShortVersionString was not found in the application bundle."
        }
    }
}
