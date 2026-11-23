import Foundation
import libdawn

extension SettingsStore {
    static func validate(_ document: SettingsDocument) throws(SettingsStoreError) {
        var workspaceIdentifiers = Set<UUID>()

        try validate(document.generalSettings)
        for workspace in document.workspaces {
            guard workspaceIdentifiers.insert(workspace.id).inserted else {
                throw .duplicateWorkspaceIdentifier(workspace.id)
            }

            try validate(workspace)
        }
    }

    static func validate(_ workspace: Workspace) throws(SettingsStoreError) {
        let trimmedName = workspace.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedName.isEmpty else {
            throw .emptyWorkspaceName
        }

        let trimmedSymbol = workspace.symbol.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedSymbol.isEmpty else {
            throw .emptyWorkspaceSymbol
        }

        var applicationIdentifiers = Set<UUID>()
        var bundleIdentifiers = Set<String>()

        for application in workspace.applications {
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

            let normalizedBundleIdentifier = trimmedBundleIdentifier.lowercased()

            guard applicationIdentifiers.insert(normalizedBundleIdentifier).inserted else {
                throw .duplicateApplication(bundleIdentifier: application.bundleIdentifier)
            }
        }
    }
}
