//
//  AboutMetadataLoader.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 10/09/26.
//

import Foundation

struct AboutContent: Equatable {
    let metadata: AboutMetadata
    let appVersion: String
}

enum AboutMetadataLoadingError: LocalizedError {
    case resourceNotFound
    case missingAppVersion

    var errorDescription: String? {
        switch self {
        case .resourceNotFound:
            "AboutMetadata.json was not found in the applicatoin bundle."
        case .missingAppVersion:
            "CFBundleShortVersionString was not found in the application bundle."
        }
    }
}

enum AboutMetadataLoader {
    static func load( from bundle: Bundle = .main) throws -> AboutContent {
        guard let resourceURL = bundle.url(
            forResource: "AboutMetadata",
            withExtension: "json"
        ) else {
            throw AboutMetadataLoadingError.resourceNotFound
        }

        let data = try Data(contentsOf: resourceURL)
        let metadata = try JSONDecoder().decode(
            AboutMetadata.self,
            from: data
        )

        try metadata.validate()

        guard let appVersion = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String,
              !appVersion.isEmpty
        else {
            throw AboutMetadataLoadingError.missingAppVersion
        }

        return AboutContent(
            metadata: metadata,
            appVersion: appVersion
        )
    }

    static func loadRequired(
        from bundle: Bundle = .main
    ) -> AboutContent {
        do {
            return try load(from: bundle)
        } catch {
            fatalError("Failed to load About metadata: \(error)")
        }
    }
}
