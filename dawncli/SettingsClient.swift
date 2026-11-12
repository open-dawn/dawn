import ArgumentParser
import Foundation
import libdawn

enum SettingsField: String, CaseIterable, ExpressibleByArgument {
    case launchAtLogin = "launch-at-login"
    case menuBar = "menu-bar"
    case forceQuit = "force-quit"
    case analytics = "analytics"
}

enum SettingsClient {
    static func get(json: Bool, ask: AgentAsk) async throws -> String {
        try render(try await fetch(ask), json: json)
    }

    static func set(
        field: SettingsField,
        value: Bool,
        json: Bool,
        ask: AgentAsk
    ) async throws -> String {
        var settings = try await fetch(ask)

        switch field {
        case .launchAtLogin: settings.launchAtLogin = value
        case .menuBar: settings.showInMenuBar = value
        case .forceQuit: settings.forceAppsToQuit = value
        case .analytics: settings.analyticsEnabled = value
        }

        try await save(settings, ask: ask)
        return try render(settings, json: json)
    }

    static func protect(
        bundleIdentifier: String,
        displayName: String,
        json: Bool,
        ask: AgentAsk
    ) async throws -> String {
        var settings = try await fetch(ask)
        let alreadyProtected = settings.protectedApps.contains {
            $0.bundleIdentifier == bundleIdentifier
        }

        if alreadyProtected {
            throw CLIError.protectedAppExists(bundleIdentifier)
        }

        settings.protectedApps.append(
            ProtectedApplication(
                bundleIdentifier: bundleIdentifier,
                displayName: displayName
            )
        )
        try await save(settings, ask: ask)
        return try render(settings, json: json)
    }

    static func unprotect(
        bundleIdentifier: String,
        json: Bool,
        ask: AgentAsk
    ) async throws -> String {
        var settings = try await fetch(ask)
        let originalCount = settings.protectedApps.count
        settings.protectedApps.removeAll { $0.bundleIdentifier == bundleIdentifier }

        if settings.protectedApps.count == originalCount {
            throw CLIError.protectedAppMissing(bundleIdentifier)
        }

        try await save(settings, ask: ask)
        return try render(settings, json: json)
    }

    private static func fetch(_ ask: AgentAsk) async throws -> Settings {
        let reply = try await ask(.getSettings(GetSettingsEvent()))

        switch reply {
        case let .settingsFetched(payload):
            return payload.settings
        case let .availableSettings(payload):
            return payload.settings
        default:
            throw AgentError.unexpectedResponse(reply.kind)
        }
    }

    private static func save(_ settings: Settings, ask: AgentAsk) async throws {
        let reply = try await ask(.updateSettings(UpdateSettingsEvent(settings: settings)))

        guard case let .settingsMutationAcknowledgement(acknowledgement) = reply else {
            throw AgentError.unexpectedResponse(reply.kind)
        }

        if case let .failure(failure) = acknowledgement {
            throw failure
        }
    }

    private static func render(_ settings: Settings, json: Bool) throws -> String {
        if json {
            return try CLIJSON.encode(settings)
        }

        return text(settings)
    }

    private static func text(_ settings: Settings) -> String {
        let apps = settings.protectedApps.map { app in
            "  \(app.displayName) (\(app.bundleIdentifier))"
        }
        let appBlock = apps.isEmpty ? "  none" : apps.joined(separator: "\n")

        return """
        Launch at login: \(settings.launchAtLogin)
        Menu bar: \(settings.showInMenuBar)
        Force quit: \(settings.forceAppsToQuit)
        Analytics: \(settings.analyticsEnabled)
        Protected apps:
        \(appBlock)
        """
    }
}
