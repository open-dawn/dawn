//
//  ApplicationBuild.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

import Foundation

enum ApplicationBuildLoadingError: Error, Equatable {
    case missingBuild
}

enum ApplicationBuild {
    static func load(
            from bundle: Bundle = .main
        ) throws -> String {
            try load(from: bundle.infoDictionary)
        }

        static func load(
            from infoDictionary: [String: Any]?
        ) throws -> String {
            guard
                let build =
                    infoDictionary?["CFBundleVersion"] as? String,
                !build.isEmpty
            else {
                throw ApplicationBuildLoadingError.missingBuild
            }

            return build
        }
}
