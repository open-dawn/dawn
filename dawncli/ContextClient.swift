import AppKit
import Foundation
import libdawn

typealias AgentAsk = @Sendable (Event) async throws -> Event

struct ContextMutationResult: Codable, Equatable {
    let contextID: UUID
}

struct ContextEdits: Equatable {
    var name: String?
    var symbol: String?
    var bundleIdentifiers: [String]?
    var activation: WorkspaceActivationPolicy?
    var terminalCommand: String?
    var clearsTerminalCommand = false
}

enum ContextClient {
    static func list(
        archivedOnly: Bool,
        json: Bool,
        ask: AgentAsk
    ) async throws -> String {
        let contexts = try await fetch(ask).filter { context in
            archivedOnly ? context.isArchived : true
        }

        if json {
            return try CLIJSON.encode(contexts)
        }

        return table(contexts)
    }

    static func show(id: UUID, json: Bool, ask: AgentAsk) async throws -> String {
        guard let context = try await fetch(ask).first(where: { $0.id == id }) else {
            throw CLIError.contextNotFound(id)
        }

        if json {
            return try CLIJSON.encode(context)
        }

        return details(context)
    }

    static func mutate(
        id: UUID,
        verb: String,
        event: Event,
        json: Bool,
        ask: AgentAsk
    ) async throws -> String {
        let contextID = try acknowledgedID(try await ask(event), expected: id)

        if json {
            return try CLIJSON.encode(ContextMutationResult(contextID: contextID))
        }

        return "\(verb) \(contextID.uuidString)"
    }

    static func create(
        request: CreateContextEvent,
        json: Bool,
        ask: AgentAsk
    ) async throws -> String {
        let contextID = try acknowledgedID(
            try await ask(.createContext(request)),
            expected: nil
        )

        if json {
            return try CLIJSON.encode(ContextMutationResult(contextID: contextID))
        }

        return "created \(contextID.uuidString)"
    }

    static func update(
        id: UUID,
        edits: ContextEdits,
        replacement: WorkspaceContext?,
        json: Bool,
        urlForApplication: (String) -> URL? = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        },
        ask: AgentAsk
    ) async throws -> String {
        let context = try await contextToSave(
            id: id,
            edits: edits,
            replacement: replacement,
            urlForApplication: urlForApplication,
            ask: ask
        )

        return try await mutate(
            id: id,
            verb: "updated",
            event: .updateContext(UpdateContextEvent(context: context)),
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

    private static func contextToSave(
        id: UUID,
        edits: ContextEdits,
        replacement: WorkspaceContext?,
        urlForApplication: (String) -> URL?,
        ask: AgentAsk
    ) async throws -> WorkspaceContext {
        if let replacement {
            guard replacement.id == id else {
                throw CLIError.contextIdentifierMismatch(expected: id, received: replacement.id)
            }
            return replacement
        }

        let resolvedApplications = try edits.bundleIdentifiers.map {
            try applications(from: $0, urlForApplication: urlForApplication)
        }

        guard var context = try await fetch(ask).first(where: { $0.id == id }) else {
            throw CLIError.contextNotFound(id)
        }

        if let name = edits.name {
            context.name = name
        }
        if let symbol = edits.symbol {
            context.symbol = symbol
        }
        if let resolvedApplications {
            context.applications = resolvedApplications
        }
        if let activation = edits.activation {
            context.transition.activationPolicy = activation
        }
        if edits.clearsTerminalCommand {
            context.transition.terminalCommand = nil
        } else if let terminalCommand = edits.terminalCommand {
            context.transition.terminalCommand = terminalCommand
        }

        return context
    }

    private static func acknowledgedID(_ reply: Event, expected: UUID?) throws -> UUID {
        guard case let .contextMutationAcknowledged(acknowledgement) = reply else {
            throw AgentError.unexpectedResponse(reply.kind)
        }

        switch acknowledgement {
        case let .success(contextID):
            if let expected, contextID != expected {
                throw CLIError.contextIdentifierMismatch(
                    expected: expected,
                    received: contextID
                )
            }
            return contextID
        case let .failure(failure):
            throw failure
        }
    }

    static func fetch(_ ask: AgentAsk) async throws -> [WorkspaceContext] {
        let reply = try await ask(.getContexts(GetContextsEvent()))

        switch reply {
        case let .contextsFetched(payload):
            return payload.contexts
        case let .availableContexts(payload):
            return payload.contexts
        default:
            throw AgentError.unexpectedResponse(reply.kind)
        }
    }

    private static func table(_ contexts: [WorkspaceContext]) -> String {
        guard !contexts.isEmpty else { return "No contexts." }

        let header = ["NAME", "SYMBOL", "ID", "APPS", "STATE"]
        let rows = contexts.map { context in
            [
                context.name,
                context.symbol,
                context.id.uuidString,
                String(context.applications.count),
                context.isArchived ? "archived" : "live"
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

    private static func details(_ context: WorkspaceContext) -> String {
        let apps = context.applications.map { app in
            "  \(app.displayName) (\(app.bundleIdentifier))"
        }
        let appBlock = apps.isEmpty ? "  none" : apps.joined(separator: "\n")
        let terminal = context.transition.terminalCommand ?? "none"

        return """
        \(context.name) (\(context.symbol))
          id: \(context.id.uuidString)
          archived: \(context.isArchived ? "yes" : "no")
          activation: \(context.transition.activationPolicy.rawValue)
          terminal command: \(terminal)
          apps:
        \(appBlock)
        """
    }
}
