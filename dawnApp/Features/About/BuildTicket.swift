//
//  BuildTicket.swift
//  dawn
//
//  Created by Longhi on 21/10/26.
//

import Foundation

enum BuildTicketValidationError: LocalizedError, Equatable {
    case emptyValue(field: String)
    case invalidYear
    case invalidCommitSHA
    case invalidURL(field: String)

    var errorDescription: String? {
        switch self {
        case .emptyValue(let field):
            "\(field) cannot be empty"
        case .invalidYear:
            "The year must contain four digits."
        case .invalidCommitSHA:
            "The commit SHA must contain at least seven hexadecimal characters."
        case .invalidURL(let field):
            "\(field) must be an absolute HTTPS URL"
        }
    }
}

struct BuildTicket: Equatable {
    let copyright: String
    let marketingURL: URL
    let license: String
    let licenseURL: URL
    let commit: Commit
    let privacyPolicyURL: URL
    let termsOfServiceURL: URL

    struct Commit: Equatable {
        let sha: String
        let reference: String
        let url: URL

        var displayName: String {
            "(\(sha.prefix(7)) \(reference))"
        }
    }

    init(
        copyright: String,
        license: String,
        licenseURL: String,
        marketingURL: String,
        privacyPolicyURL: String,
        termsOfServiceURL: String,
        year: String,
        sha: String,
        reference: String,
        repositoryURL: String
    ) throws {
        let trimmedYear = try Self.year(from: year)
        let trimmedSHA = try Self.commitSHA(sha)
        let repository = try Self.httpsURL(
            Self.removingTrailingSlashes(repositoryURL),
            field: "repositoryURL"
        )

        self.copyright = try Self.copyright(copyright, year: trimmedYear)
        self.license = try Self.requiredValue(license, field: "license")
        self.licenseURL = try Self.httpsURL(licenseURL, field: "licenseURL")
        self.marketingURL = try Self.httpsURL(
            marketingURL,
            field: "marketingURL"
        )
        self.commit = Commit(
            sha: trimmedSHA,
            reference: try Self.requiredValue(reference, field: "reference"),
            url: try Self.httpsURL(
                "\(repository.absoluteString)/commit/\(trimmedSHA)",
                field: "commit.url"
            )
        )
        self.privacyPolicyURL = try Self.httpsURL(
            privacyPolicyURL,
            field: "privacyPolicyURL"
        )
        self.termsOfServiceURL = try Self.httpsURL(
            termsOfServiceURL,
            field: "termsOfServiceURL"
        )
    }

    private static func year(from value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 4,
              trimmed.allSatisfy({ $0.isNumber && $0.isASCII })
        else {
            throw BuildTicketValidationError.invalidYear
        }
        return trimmed
    }

    private static func copyright(
        _ value: String,
        year: String
    ) throws -> String {
        try requiredValue(
            value.replacingOccurrences(of: "{year}", with: year),
            field: "copyright"
        )
    }

    private static func requiredValue(
        _ value: String,
        field: String
    ) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BuildTicketValidationError.emptyValue(field: field)
        }
        return trimmed
    }

    private static func commitSHA(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 7,
              trimmed.allSatisfy(\.isHexDigit)
        else {
            throw BuildTicketValidationError.invalidCommitSHA
        }
        return trimmed
    }

    private static func removingTrailingSlashes(_ value: String) -> String {
        var result = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        while result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }

    private static func httpsURL(
        _ string: String,
        field: String
    ) throws -> URL {
        guard let url = URL(string: string),
              url.scheme?.lowercased() == "https",
              url.host != nil
        else {
            throw BuildTicketValidationError.invalidURL(field: field)
        }
        return url
    }
}
