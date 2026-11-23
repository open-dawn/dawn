import AppKit
import Foundation
import libdawn

typealias AgentAsk = @Sendable (Event) async throws -> Event

struct WorkspaceMutationResult: Codable, Equatable {
    let workspaceID: UUID
}

struct WorkspaceEdits: Equatable {
    var name: String?
    var symbol: String?
    var bundleIdentifiers: [String]?
    var clearsApplications = false
    var activation: WorkspaceActivationPolicy?
    var terminalCommand: String?
    var clearsTerminalCommand = false
}

enum WorkspaceClient {
    static func list(
        archivedOnly: Bool,
        json: Bool,
        ask: AgentAsk
    ) async throws -> String {
        let workspaces = try await fetch(ask).filter { workspace in
            archivedOnly ? workspace.isArchived : true
        }

        if json {
            return try CLIJSON.encode(workspaces)
        }

        return table(workspaces)
    }

    static func show(id: UUID, json: Bool, ask: AgentAsk) async throws -> String {
        guard let workspace = try await fetch(ask).first(where: { $0.id == id }) else {
            throw CLIError.workspaceNotFound(id)
        }

        if json {
            return try CLIJSON.encode(workspace)
        }

        return details(workspace)
    }

    static func mutate(
        id: UUID,
        verb: String,
        event: Event,
        json: Bool,
        ask: AgentAsk
    ) async throws -> String {
        let workspaceID = try acknowledgedID(try await ask(event), expected: id)

        if json {
            return try CLIJSON.encode(WorkspaceMutationResult(workspaceID: workspaceID))
        }

        return "\(verb) \(workspaceID.uuidString)"
    }

    static func create(
        request: CreateWorkspaceEvent,
        json: Bool,
        ask: AgentAsk
    ) async throws -> String {
        let workspaceID = try acknowledgedID(
            try await ask(.createWorkspace(request)),
            expected: nil
        )

        if json {
            return try CLIJSON.encode(WorkspaceMutationResult(workspaceID: workspaceID))
        }

        return "created \(workspaceID.uuidString)"
    }

    static func update(
        id: UUID,
        edits: WorkspaceEdits,
        replacement: Workspace?,
        json: Bool,
        urlForApplication: (String) -> URL? = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        },
        ask: AgentAsk
    ) async throws -> String {
        let workspace = try await workspaceToSave(
            id: id,
            edits: edits,
            replacement: replacement,
            urlForApplication: urlForApplication,
            ask: ask
        )

        return try await mutate(
            id: id,
            verb: "updated",
            event: .updateWorkspace(UpdateWorkspaceEvent(workspace: workspace)),
            json: json,
            ask: ask
        )
    }

    static func applications(
        from bundleIdentifiers: [String],
        urlForApplication: (String) -> URL? = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        }
    ) throws -> [WorkspaceApplication] {
        try bundleIdentifiers.map { bundleIdentifier in
            guard let applicationURL = urlForApplication(bundleIdentifier) else {
                throw CLIError.applicationNotFound(bundleIdentifier)
            }

            let bundle = Bundle(url: applicationURL)
            let displayName =
                bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? applicationURL.deletingPathExtension().lastPathComponent

            return WorkspaceApplication(
                bundleIdentifier: bundleIdentifier,
                displayName: displayName,
                applicationURL: applicationURL
            )
        }
    }

    private static func workspaceToSave(
        id: UUID,
        edits: WorkspaceEdits,
        replacement: Workspace?,
        urlForApplication: (String) -> URL?,
        ask: AgentAsk
    ) async throws -> Workspace {
        if let replacement {
            guard replacement.id == id else {
                throw CLIError.workspaceIdentifierMismatch(expected: id, received: replacement.id)
            }
            return replacement
        }

        let resolvedApplications = try edits.bundleIdentifiers.map {
            try applications(from: $0, urlForApplication: urlForApplication)
        }

        guard var workspace = try await fetch(ask).first(where: { $0.id == id }) else {
            throw CLIError.workspaceNotFound(id)
        }

        if let name = edits.name {
            workspace.name = name
        }
        if let symbol = edits.symbol {
            workspace.symbol = symbol
        }
        if edits.clearsApplications {
            workspace.applications = []
        } else if let resolvedApplications {
            workspace.applications = resolvedApplications
        }
        if let activation = edits.activation {
            workspace.transition.activationPolicy = activation
        }
        if edits.clearsTerminalCommand {
            workspace.transition.terminalCommand = nil
        } else if let terminalCommand = edits.terminalCommand {
            workspace.transition.terminalCommand = terminalCommand
        }

        return workspace
    }

    private static func acknowledgedID(_ reply: Event, expected: UUID?) throws -> UUID {
        guard case let .workspaceMutationAcknowledged(acknowledgement) = reply else {
            throw AgentError.unexpectedResponse(reply.kind)
        }

        switch acknowledgement {
        case let .success(workspaceID):
            if let expected, workspaceID != expected {
                throw CLIError.workspaceIdentifierMismatch(
                    expected: expected,
                    received: workspaceID
                )
            }
            return workspaceID
        case let .failure(failure):
            throw failure
        }
    }

    static func fetch(_ ask: AgentAsk) async throws -> [Workspace] {
        let reply = try await ask(.getWorkspaces(GetWorkspacesEvent()))

        switch reply {
        case let .workspacesFetched(payload):
            return payload.workspaces
        case let .availableWorkspaces(payload):
            return payload.workspaces
        default:
            throw AgentError.unexpectedResponse(reply.kind)
        }
    }

    private static func table(_ workspaces: [Workspace]) -> String {
        guard !workspaces.isEmpty else { return "No workspaces." }

        let header = ["NAME", "SYMBOL", "ID", "APPS", "STATE"]
        let rows = workspaces.map { workspace in
            [
                workspace.name,
                workspace.symbol,
                workspace.id.uuidString,
                String(workspace.applications.count),
                workspace.isArchived ? "archived" : "live"
            ]
        }
        let widths = header.indices.map { column in
            let values = rows.map { $0[column].count }
            return max(header[column].count, values.max() ?? 0)
        }
        let lines = ([header] + rows).map { row in
            row.enumerated().map { index, value in
                guard index < widths.count - 1 else { return value }
                return value.padding(toLength: widths[index], withPad: " ", startingAt: 0)
            }
            .joined(separator: "  ")
        }

        return lines.joined(separator: "\n")
    }

    private static func details(_ workspace: Workspace) -> String {
        let apps = workspace.applications.map { app in
            "  \(app.displayName) (\(app.bundleIdentifier))"
        }
        let appBlock = apps.isEmpty ? "  none" : apps.joined(separator: "\n")
        let terminal = workspace.transition.terminalCommand ?? "none"

        return """
        \(workspace.name) (\(workspace.symbol))
          id: \(workspace.id.uuidString)
          archived: \(workspace.isArchived ? "yes" : "no")
          activation: \(workspace.transition.activationPolicy.rawValue)
          terminal command: \(terminal)
          apps:
        \(appBlock)
        """
    }
}
