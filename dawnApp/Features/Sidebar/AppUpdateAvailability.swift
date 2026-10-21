import Foundation

struct AppUpdateAvailability: Equatable, Sendable {
    let version: String
    let releaseURL: URL
}
