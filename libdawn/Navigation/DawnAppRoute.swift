//
//  DawnAppRoute.swift
//  dawn
//
//  Created by Rafael Venetikides on 22/10/26.
//

import Foundation

public enum DawnAppRoute: Hashable, Sendable {
    public static let scheme = "opendawn"

    case settings
    case context(UUID)

    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme

        switch self {
        case .settings:
            components.host = "settings"

        case .context(let uUID):
            components.host = "context"
            components.path = "/\(uUID.uuidString)"
        }

        guard let url = components.url else {
            preconditionFailure("Failed to encode a valid DAWN route")
        }

        return url
    }

    public init?(url: URL) {
        guard let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ),
              components.scheme?.lowercased() == Self.scheme,
              components.query == nil,
              components.fragment == nil
        else {
            return nil
        }

        let pathComponents = components.path.split(
            separator: "/",
            omittingEmptySubsequences: true
        )

        switch components.host?.lowercased() {
        case "settings":
            guard pathComponents.isEmpty else {
                return nil
            }

            self = .settings

        case "context":
            guard pathComponents.count == 1,
                  let contextID = UUID(uuidString: String(pathComponents[0])) else {
                return nil
            }

            self = .context(contextID)

        default:
            return nil
        }
    }
}
