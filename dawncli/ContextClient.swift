import Foundation
import libdawn

typealias AgentAsk = @Sendable (Event) async throws -> Event

struct ContextMutationResult: Codable, Equatable {
    let contextID: UUID
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

    private static func acknowledgedID(_ reply: Event, expected: UUID) throws -> UUID {
        guard case let .contextMutationAcknowledged(acknowledgement) = reply else {
            throw AgentError.unexpectedResponse(reply.kind)
        }

        switch acknowledgement {
        case let .success(contextID):
            guard contextID == expected else {
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
