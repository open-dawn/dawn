import Foundation
import libdawn

extension SettingsStore {
    static func validate(_ document: SettingsDocument) throws(SettingsStoreError) {
        var contextIdentifiers = Set<UUID>()

        try validate(document.generalSettings)
        for context in document.contexts {
            guard contextIdentifiers.insert(context.id).inserted else {
                throw .duplicateContextIdentifier(context.id)
            }

            try validate(context)
        }
    }

    static func validate(_ context: WorkspaceContext) throws(SettingsStoreError) {
        let trimmedName = context.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedName.isEmpty else {
            throw .emptyContextName
        }

        let trimmedSymbol = context.symbol.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedSymbol.isEmpty else {
            throw .emptyContextSymbol
        }

        var applicationIdentifiers = Set<UUID>()
        var bundleIdentifiers = Set<String>()

        for application in context.applications {
            try validate(application)

            guard applicationIdentifiers.insert(application.id).inserted else {
                throw .duplicateApplicationIdentifier(
                    application.id
                )
            }

            let normalizedBundleIdentifier = application.bundleIdentifier
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            guard bundleIdentifiers.insert(normalizedBundleIdentifier).inserted else {
                throw .duplicateApplication(
                    bundleIdentifier: application.bundleIdentifier
                )
            }
        }
    }

    static func validate(_ application: WorkspaceApplication) throws(SettingsStoreError) {
        let trimmedBundleIdentifier = application.bundleIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedBundleIdentifier.isEmpty else {
            throw .emptyApplicationBundleIdentifier
        }

        let trimmedDisplayName = application.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedDisplayName.isEmpty else {
            throw .emptyApplicationDisplayName
        }
    }

    static func validate(_ settings: Settings) throws(SettingsStoreError) {
        var applicationIdentifiers = Set<String>()
        for application in settings.protectedApps {
            let trimmedBundleIdentifier = application.bundleIdentifier
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedBundleIdentifier.isEmpty else {
                throw .emptyApplicationBundleIdentifier
            }

            let trimmedDisplayName = application.displayName
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedDisplayName.isEmpty else {
                throw .emptyApplicationDisplayName
            }

            guard applicationIdentifiers.insert(application.bundleIdentifier).inserted else {
                throw .duplicateApplication(bundleIdentifier: application.bundleIdentifier)
            }
        }
    }
}
