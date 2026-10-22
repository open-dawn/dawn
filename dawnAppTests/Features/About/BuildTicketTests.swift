//
//  BuildTicketTests.swift
//  dawn
//
//  Created by Longhi on 21/10/26.
//

@testable import dawnApp
import Foundation
import Testing

@Suite("Build ticket")
struct BuildTicketTests {
    @Test("derives ticket fields from build inputs")
    func derivesTicketFields() throws {
        let ticket = try makeTicket()

        #expect(ticket.copyright == "Copyright © 2026 Open Dawn Team")
        #expect(ticket.license == "GNU GPLv3")
        #expect(
            ticket.licenseURL.absoluteString
                == "https://www.gnu.org/licenses/gpl-3.0.html"
        )
        #expect(
            ticket.marketingURL.absoluteString
                == "https://github.com/open-dawn/dawn"
        )
        #expect(ticket.commit.displayName == "(2b94d72 stable)")
        #expect(
            ticket.commit.url.absoluteString
                == "https://github.com/open-dawn/dawn/commit/\(sampleSHA)"
        )
        #expect(
            ticket.privacyPolicyURL.absoluteString
                == "https://github.com/open-dawn/dawn"
        )
        #expect(
            ticket.termsOfServiceURL.absoluteString
                == "https://github.com/open-dawn/dawn"
        )
    }

    @Test("rejects a year that is not four digits")
    func rejectsInvalidYear() {
        #expect(throws: BuildTicketValidationError.invalidYear) {
            try makeTicket(year: "26")
        }
    }

    @Test("rejects an empty reference")
    func rejectsEmptyReference() {
        #expect(throws: BuildTicketValidationError.emptyValue(field: "reference")) {
            try makeTicket(reference: " \n ")
        }
    }

    @Test("rejects an invalid commit SHA")
    func rejectsInvalidCommitSHA() {
        #expect(throws: BuildTicketValidationError.invalidCommitSHA) {
            try makeTicket(sha: "11--fd")
        }
    }

    @Test("rejects a non-HTTPS repository URL")
    func rejectsNonHTTPSRepositoryURL() {
        #expect(throws: BuildTicketValidationError.invalidURL(field: "repositoryURL")) {
            try makeTicket(repositoryURL: "http://example.com/dawn")
        }
    }

    @Test("rejects a non-HTTPS license URL")
    func rejectsNonHTTPSLicenseURL() {
        #expect(throws: BuildTicketValidationError.invalidURL(field: "licenseURL")) {
            try makeTicket(licenseURL: "http://example.com/license")
        }
    }

    private let sampleSHA = "2b94d72b4578ddad0892af886f37739d1f1a396f"

    private func makeTicket(
        copyright: String = "Copyright © {year} Open Dawn Team",
        license: String = "GNU GPLv3",
        licenseURL: String = "https://www.gnu.org/licenses/gpl-3.0.html",
        marketingURL: String = "https://github.com/open-dawn/dawn",
        privacyPolicyURL: String = "https://github.com/open-dawn/dawn",
        termsOfServiceURL: String = "https://github.com/open-dawn/dawn",
        year: String = "2026",
        sha: String? = nil,
        reference: String = "stable",
        repositoryURL: String = "https://github.com/open-dawn/dawn"
    ) throws -> BuildTicket {
        try BuildTicket(
            copyright: copyright,
            license: license,
            licenseURL: licenseURL,
            marketingURL: marketingURL,
            privacyPolicyURL: privacyPolicyURL,
            termsOfServiceURL: termsOfServiceURL,
            year: year,
            sha: sha ?? sampleSHA,
            reference: reference,
            repositoryURL: repositoryURL
        )
    }
}
