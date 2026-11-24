import Foundation

struct UpdateInstallationIdentity: Sendable {
    static let userDefaultsKey = "app.opendawn.update.installationID"

    let installationID: String

    static func loadOrCreate(
        userDefaults: UserDefaults = .standard
    ) -> UpdateInstallationIdentity {
        if let existing = userDefaults.string(forKey: userDefaultsKey),
           UUID(uuidString: existing) != nil {
            return UpdateInstallationIdentity(installationID: existing.lowercased())
        }

        let created = UUID().uuidString.lowercased()
        userDefaults.set(created, forKey: userDefaultsKey)
        return UpdateInstallationIdentity(installationID: created)
    }
}
