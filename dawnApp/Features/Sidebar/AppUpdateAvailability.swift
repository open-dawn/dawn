// NEEDS REVIEW — PIN-132 (sidebar design): changed in this issue, pending organization review.
import Foundation

struct AppUpdateAvailability: Equatable, Sendable {
    let version: String
    let releaseURL: URL
}
