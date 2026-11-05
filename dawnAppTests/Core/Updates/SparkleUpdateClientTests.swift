//
//  SparkleUpdateClientTests.swift
//  dawn
//
//  Created by Rafael Venetikides on 01/11/26.
//

import Foundation
import Sparkle
import Testing

@testable import dawnApp

@MainActor
@Suite("Sparkle update client")
struct SparkleUpdateClientTests {
    @Test("Sparkle no-update reasons map to application reasons")
    func noUpdateReasonsAreMapped() {
        let cases:
            [(
                SPUNoUpdateFoundReason,
                AppUpdateUnavailabilityReason
            )] = [
                (.onLatestVersion, .currentVersionIsLatest),
                (.onNewerThanLatestVersion, .currentVersionIsNewer),
                (.systemIsTooOld, .systemIsTooOld),
                (.systemIsTooNew, .systemIsTooNew),
                (.hardwareDoesNotSupportARM64, .unsupportedHardware),
                (.unknown, .unknown),
            ]

        for (sparkleReason, expectedReason) in cases {
            let error = NSError(
                domain: SUSparkleErrorDomain,
                code: 0,
                userInfo: [
                    SPUNoUpdateFoundReasonKey:
                        NSNumber(value: sparkleReason.rawValue)
                ]
            )

            #expect(
                SparkleUpdateClient.unavailabilityReason(
                    from: error
                ) == expectedReason
            )
        }
    }

    @Test("Missing Sparkle reason maps to unknown")
    func missingNoUpdateReason() {
        let error = NSError(
            domain: SUSparkleErrorDomain,
            code: 0
        )

        #expect(
            SparkleUpdateClient.unavailabilityReason(
                from: error
            ) == .unknown
        )
    }

    @Test("Wrapped network errors map to network unavailable")
    func wrappedNetworkError() {
        let networkError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet
        )

        let sparkleError = NSError(
            domain: SUSparkleErrorDomain,
            code: Int(SUError.downloadError.rawValue),
            userInfo: [
                NSUnderlyingErrorKey: networkError
            ]
        )

        #expect(
            SparkleUpdateClient.failureReason(
                from: sparkleError
            ) == .networkUnavailable
        )
    }

    @Test("Sparkle failures map to application failure reasons")
    func failureReasonsAreMapped() {
        let cases:
            [(
                SUError,
                AppUpdateFailureReason
            )] = [
                (.insecureFeedURLError, .invalidFeed),
                (.invalidFeedURLError, .invalidFeed),
                (.appcastParseError, .invalidFeed),

                (.invalidHostVersionError, .invalidMetadata),
                (.appcastError, .invalidMetadata),

                (.noPublicDSAFoundError, .updaterUnavailable),
                (.insufficientSigningError, .updaterUnavailable),
                (.invalidUpdaterError, .updaterUnavailable),
                (
                    .invalidHostBundleIdentifierError,
                    .updaterUnavailable
                ),

                (.signatureError, .invalidUpdate),
                (.validationError, .invalidUpdate),
                (.notValidUpdateError, .invalidUpdate),

                (.installationError, .installationFailed),
                (.authenticationFailure, .installationFailed),
            ]

        for (sparkleError, expectedReason) in cases {
            let error = NSError(
                domain: SUSparkleErrorDomain,
                code: Int(sparkleError.rawValue)
            )

            #expect(
                SparkleUpdateClient.failureReason(
                    from: error
                ) == expectedReason
            )
        }
    }

    @Test("Unknown errors map to unknown")
    func unknownFailure() {
        let error = NSError(
            domain: "test.error",
            code: 1
        )

        #expect(
            SparkleUpdateClient.failureReason(
                from: error
            ) == .unknown
        )
    }

    @Test("Download error without network cause maps to unknown")
    func downloadErrorWithoutNetworkCause() {
        let error = NSError(
            domain: SUSparkleErrorDomain,
            code: Int(SUError.downloadError.rawValue)
        )

        #expect(
            SparkleUpdateClient.failureReason(
                from: error
            ) == .unknown
        )
    }
}
