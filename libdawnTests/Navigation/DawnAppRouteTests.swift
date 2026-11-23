//
//  DawnAppRouteTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 22/10/26.
//

import Foundation
import Testing

@testable import libdawn

@Suite("DAWN app route")
struct DawnAppRouteTests {
    @Test("encodes and decodes a workspace route")
    func workspaceRouteRoundTrip() async throws {
        let workspaceID = UUID()
        let route = DawnAppRoute.workspace(workspaceID)

        #expect(route.url.absoluteString == "opendawn://workspace/\(workspaceID.uuidString)")
        #expect(DawnAppRoute(url: route.url) == route)
    }

    @Test("encodes and decodes the settings route")
    func settingsRouteRoundTrip() {
        let route = DawnAppRoute.settings

        #expect(route.url.absoluteString == "opendawn://settings")
        #expect(DawnAppRoute(url: route.url) == route)
    }

    @Test("encodes and decodes the app route")
    func appRouteRoundTrip() async throws {
        let route = DawnAppRoute.application

        #expect(route.url.absoluteString == "opendawn://app")
        #expect(DawnAppRoute(url: route.url) == route)
    }

    @Test("rejects unsopported URLs")
    func rejectsUnsupportedURLs() throws {
        let invalidURLs = [
            "https://workspace/\(UUID().uuidString)",
            "opendawn://unkown",
            "opendawn://workspace",
            "opendawn://workspace/not-a-uuid",
            "opendawn://workspace/\(UUID().uuidString)/extra",
            "opendawn://settings/unexpected",
        ]

        for rawURL in invalidURLs {
            let url = try #require(URL(string: rawURL))

            #expect(DawnAppRoute(url: url) == nil)
        }
    }
}
