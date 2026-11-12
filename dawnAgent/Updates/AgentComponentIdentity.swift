//
//  AgentComponentIdentity.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

import Foundation
import libdawn

enum AgentComponentIdentity {
    static func load(from bundle: Bundle = .main) throws -> ComponentIdentity {
        guard let identifier = bundle.bundleIdentifier, !identifier.isEmpty else {
            throw AgentComponentIdentityLoadingError.missingBundleIdentifier
        }

        guard
            let version = bundle.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String, !version.isEmpty
        else {
            throw AgentComponentIdentityLoadingError.missingVersion
        }

        guard let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String, !build.isEmpty else {
            throw AgentComponentIdentityLoadingError.missingBuild
        }

        return ComponentIdentity(
            identifier: identifier,
            version: version,
            build: build
        )
    }
}

enum AgentComponentIdentityLoadingError: LocalizedError {
    case missingBundleIdentifier
    case missingVersion
    case missingBuild

    var errorDescription: String? {
        switch self {
        case .missingBundleIdentifier:
            "The dawnAgent bundle identifier is missing."
        case .missingVersion:
            "CFBundleShortVersionString is missing from dawnAgent."
        case .missingBuild:
            "CFBundleVersion is missing from dawnAgent."
        }
    }
}
