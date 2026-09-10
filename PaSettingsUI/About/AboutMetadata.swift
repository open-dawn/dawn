//
//  AboutMetadata.swift
//  pineapplewm
//
//  Created by Rafael Venetikides on 09/09/26.
//

import Foundation

enum AboutMetadataValidationError: LocalizedError, Equatable {
    case emptyValue(field: String)
    case invalidCommitSHA
    case invalidURL(field: String)

    var errorDescription: String? {
        switch self {
        case .emptyValue(let field):
            "\(field) cannot be empty"
        case .invalidCommitSHA:
            "The commit SHA must contain at leat seven hexadecimal characters."
        case .invalidURL(let field):
            "\(field) must be an absolute HTTPS URL"
        }
    }
}

struct AboutMetadata: Decodable, Equatable {
    let copyright: String
    let license: String
    let commit: Commit
    let privacyPolicyURL: URL
    let termsOfUseURL: URL

    struct Commit: Decodable, Equatable {
        let sha: String
        let reference: String
        let url: URL

        var displayName: String {
            "\(sha.prefix(7)) (\(reference))"
        }
    }

    func validate() throws {
        try requireValue(copyright, field: "copyright")
        try requireValue(license, field: "license")
        try requireValue(commit.reference, field: "commit.reference")

        guard commit.sha.count >= 7,
              commit.sha.allSatisfy({ $0.isHexDigit })
        else {
            throw AboutMetadataValidationError.invalidCommitSHA
        }

        try requireHTTPSURL(commit.url, field: "commit.url")
        try requireHTTPSURL(privacyPolicyURL, field: "privacyPolicyURL")
        try requireHTTPSURL(termsOfUseURL, field: "termsOfUseURL")
    }

    private func requireValue(
        _ value: String,
        field: String
    ) throws {
        guard !value.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            throw AboutMetadataValidationError.emptyValue(field: field)
        }
    }

    private func requireHTTPSURL(
        _ url: URL,
        field: String
    ) throws {
        guard url.scheme?.lowercased() == "https",
              url.host != nil
        else {
            throw AboutMetadataValidationError.invalidURL(field: field)
        }
    }
}