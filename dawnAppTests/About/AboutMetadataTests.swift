//
//  AboutMetadataTests.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 09/09/26.
//

import Foundation
import Testing

@testable import dawnApp

@Suite("About metadata")
struct AboutMetadataTests {
    @Test("decodes valid metadata")
    func decodesValidMetadata() async throws {
        let json = """
            {
              "copyright": "PineApple INC 2026",
              "license": "GNU GENERAL PUBLIC LICENSE",
              "commit": {
                "sha": "2b94d72b4578ddad0892af886f37739d1f1a396f",
                "reference": "stable",
                "url":
                "https://github.com/PineAppleIncOS/pineapplewm/commit/2b94d72b4578ddad0892af886f37739d1f1a396f"
              },
              "privacyPolicyURL": "https://example.com/privacy",
              "termsOfUseURL": "https://example.com/terms"
            }
            """

        let data = try #require(json.data(using: .utf8))
        let metadata = try JSONDecoder().decode(
            AboutMetadata.self,
            from: data
        )

        #expect(metadata.license == "GNU GENERAL PUBLIC LICENSE")
        #expect(metadata.commit.displayName == "2b94d72 (stable)")
        #expect(metadata.privacyPolicyURL.absoluteString == "https://example.com/privacy")
    }

    @Test("loads bundled metadata and application version")
    func loadsBundleMetadata() async throws {
        let content = try AboutMetadataLoader.load()

        #expect(!content.appVersion.isEmpty)
        #expect(!content.metadata.copyright.isEmpty)
        #expect(!content.metadata.license.isEmpty)
        #expect(content.metadata.commit.sha.count >= 7)
    }

    @Test("accepts valid metadata")
    func acceptsValidMetadata() async throws {
        let metadata = try makeMetadata()

        #expect(throws: Never.self) {
            try metadata.validate()
        }
    }

    @Test("rejects an empty license")
    func rejectsEmptyLicence() async throws {
        let metadata = try makeMetadata(license: " \n ")

        #expect(throws: AboutMetadataValidationError.emptyValue(field: "license")) {
            try metadata.validate()
        }
    }

    @Test("rejects invalid commit SHA")
    func rejectsInvalidCommitSHA() async throws {
        let metadata = try makeMetadata(sha: "11--fd")

        #expect(throws: AboutMetadataValidationError.invalidCommitSHA) {
            try metadata.validate()
        }
    }

    @Test("rejects a non-HTTPS URL")
    func rejectsNonHTTPSURL() async throws {
        let metadata = try makeMetadata(
            privacyPolicyURL: "http://example.com/privacy"
        )

        #expect(throws: AboutMetadataValidationError.invalidURL(field: "privacyPolicyURL")) {
            try metadata.validate()
        }
    }

    private func makeMetadata(
        copyright: String = "PineApple INC 2026",
        license: String = "GNU GENERAL PUBLIC LICENSE",
        sha: String = "2b94d72b4578ddad0892af886f37739d1f1a396f",
        reference: String = "stable",
        commitURL: String = "https://github.com/PineAppleIncOS/pineapplewm",
        privacyPolicyURL: String = "https://example.com/privacy",
        termsOfUseURL: String = "https://example.com/terms"
    ) throws -> AboutMetadata {
        let parsedCommitURL = try #require(URL(string: commitURL))
        let parsedPrivacyURL = try #require(URL(string: privacyPolicyURL))
        let parsedTermsURL = try #require(URL(string: termsOfUseURL))

        return AboutMetadata(
            copyright: copyright,
            license: license,
            commit: AboutMetadata.Commit(
                sha: sha,
                reference: reference,
                url: parsedCommitURL
            ),
            privacyPolicyURL: parsedPrivacyURL,
            termsOfUseURL: parsedTermsURL
        )
    }
}
