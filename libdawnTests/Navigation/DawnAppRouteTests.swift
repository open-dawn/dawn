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
    @Test("encodes and decodes a context route")
    func contextRouteRoundTrip() async throws {
        let contextID = UUID()
        let route = DawnAppRoute.context(contextID)

        #expect(route.url.absoluteString == "opendawn://context/\(contextID.uuidString)")
        #expect(DawnAppRoute(url: route.url) == route)
    }

    @Test("encodes and decodes the settings route")
    func settingsRouteRoundTrip() {
        let route = DawnAppRoute.settings

        #expect(route.url.absoluteString == "opendawn://settings")
        #expect(DawnAppRoute(url: route.url) == route)
    }

    @Test("rejects unsopported URLs")
    func rejectsUnsupportedURLs() throws {
        let invalidURLs = [
            "https://context/\(UUID().uuidString)",
            "opendawn://unkown",
            "opendawn://context",
            "opendawn://context/not-a-uuid",
            "opendawn://context/\(UUID().uuidString)/extra",
            "opendawn://settings/unexpected",
        ]

        for rawURL in invalidURLs {
            let url = try #require(URL(string: rawURL))

            #expect(DawnAppRoute(url: url) == nil)
        }
    }
}
