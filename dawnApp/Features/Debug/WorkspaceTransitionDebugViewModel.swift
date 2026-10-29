#if DEBUG

import Foundation
import libdawn

@Observable
@MainActor
final class WorkspaceTransitionDebugViewModel {
    private let applicationSelector: any ApplicationSelecting

    var activationPolicy: WorkspaceActivationPolicy = .hide
    var terminalCommand = ""
    var applications: [WorkspaceApplication] = []
    var cleanupAfterRun = true
    var selectedExistingContextID: UUID?

    private(set) var isRunning = false
    private(set) var logEntries: [String] = []
    private(set) var applicationSelectionError: ApplicationSelectionError?

    init(applicationSelector: any ApplicationSelecting = SystemApplicationSelector()) {
        self.applicationSelector = applicationSelector
    }

    var transitionPreview: WorkspaceTransition {
        WorkspaceTransition(
            activationPolicy: activationPolicy,
            terminalCommand: normalizedOptional(terminalCommand)
        )
    }

    func clearLog() {
        logEntries = []
    }

    func addApplication() async {
        guard !isRunning else { return }

        applicationSelectionError = nil

        do {
            guard let application = try await applicationSelector.selectApplication() else {
                return
            }
            applications.append(application)
            appendLog("Added app \(application.displayName)")
        } catch let error as ApplicationSelectionError {
            applicationSelectionError = error
            appendLog("App selection failed: \(error.localizedDescription)")
        } catch {
            applicationSelectionError = .unknown
            appendLog("App selection failed: \(error.localizedDescription)")
        }
    }

    func removeApplication(id: UUID) {
        applications.removeAll { $0.id == id }
    }

    func runEphemeralTransition(using store: SettingsContextStore) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let transition = transitionPreview
        let name = "Debug Transition \(Self.timestamp())"
        let symbol = "ladybug"

        appendLog("Starting ephemeral transition (\(transition.activationPolicy.rawValue))…")

        do {
            let contextID = try await store.createContext(
                name: name,
                symbol: symbol,
                applications: applications
            )
            appendLog("Created context \(contextID.uuidString)")

            let context = WorkspaceContext(
                id: contextID,
                name: name,
                symbol: symbol,
                applications: applications,
                transition: transition
            )

            try await store.updateContext(context)
            appendLog(
                "Updated transition — terminal: \(transition.terminalCommand ?? "nil")"
            )

            try await store.switchContext(id: contextID)
            appendLog("Switch acknowledged — agent should be applying the transition")

            if cleanupAfterRun {
                try await store.deleteContext(id: contextID)
                appendLog("Cleaned up ephemeral context")
            } else {
                appendLog("Left context in store: \(name)")
            }

            await store.refresh()
            appendLog("Done")
        } catch {
            appendLog("FAILED: \(error.localizedDescription)")
        }
    }

    func runExistingContext(using store: SettingsContextStore) async {
        guard !isRunning else { return }
        guard let selectedExistingContextID else {
            appendLog("Pick an existing context first")
            return
        }

        isRunning = true
        defer { isRunning = false }

        let name = store.contexts.first { $0.id == selectedExistingContextID }?.name
            ?? selectedExistingContextID.uuidString
        appendLog("Switching existing context “\(name)”…")

        do {
            try await store.switchContext(id: selectedExistingContextID)
            appendLog("Switch acknowledged")
        } catch {
            appendLog("FAILED: \(error.localizedDescription)")
        }
    }

    func applyTransitionToExistingContext(using store: SettingsContextStore) async {
        guard !isRunning else { return }
        guard let selectedExistingContextID,
            var context = store.contexts.first(where: { $0.id == selectedExistingContextID })
        else {
            appendLog("Pick an existing context first")
            return
        }

        isRunning = true
        defer { isRunning = false }

        context.applications = applications
        context.transition = transitionPreview
        appendLog("Updating “\(context.name)” with current debug transition…")

        do {
            try await store.updateContext(context)
            appendLog("Context updated")
            await store.refresh()
        } catch {
            appendLog("FAILED: \(error.localizedDescription)")
        }
    }

    func sendDebugPing(using eventBusService: SettingsEventBusService) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        appendLog("Sending debugPing…")

        do {
            let response = try await eventBusService.bus.ask(
                .debugPing(DebugPingEvent()),
                timeout: .seconds(5)
            )

            if case .debugPong = response {
                appendLog("Received debugPong — agent is reachable")
            } else {
                appendLog("Unexpected reply: \(response.kind)")
            }
        } catch {
            appendLog("FAILED: \(error.localizedDescription)")
        }
    }

    func refreshContexts(using store: SettingsContextStore) async {
        appendLog("Refreshing contexts…")
        await store.refresh()
        appendLog("Contexts loaded: \(store.contexts.count)")
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func appendLog(_ message: String) {
        logEntries.append("[\(Self.timestamp())] \(message)")
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

#endif
