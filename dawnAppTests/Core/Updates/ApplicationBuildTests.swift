//
//  ApplicationBuildTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 11/11/26.
//

import Testing

@testable import dawnApp

@Suite("Application build")
struct ApplicationBuildTests {
    @Test("Loads the bundle build")
    func loadsBuild() throws {
        let build = try ApplicationBuild.load(
            from: ["CFBundleVersion": "42"]
        )

        #expect(build == "42")
    }

    @Test("Rejects a missing build")
    func rejectsMissingBuild() {
        #expect(
            throws: ApplicationBuildLoadingError.missingBuild
        ) {
            _ = try ApplicationBuild.load(from: [:])
        }
    }

    @Test("Rejects an empty build")
    func rejectsEmptyBuild() {
        #expect(
            throws: ApplicationBuildLoadingError.missingBuild
        ) {
            _ = try ApplicationBuild.load(
                from: ["CFBundleVersion": ""]
            )
        }
    }

    @Test("Rejects a non-string build")
    func rejectsNonStringBuild() {
        #expect(
            throws: ApplicationBuildLoadingError.missingBuild
        ) {
            _ = try ApplicationBuild.load(
                from: ["CFBundleVersion": 42]
            )
        }
    }
}
