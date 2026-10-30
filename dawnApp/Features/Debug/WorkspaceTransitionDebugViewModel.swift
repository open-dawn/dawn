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
    var selectedApplicationID: UUID?

    /// Defaults stamped onto newly added apps (and shown when none is selected).
    var allowsRunningApplicationSubstitution = true
    var createsNewApplicationInstance = false
    var argumentsText = ""
    var environmentText = ""
    var promptsUserIfNeeded = false
    var windowLayout: WorkspaceWindowLayout = .window

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

    var selectedApplication: WorkspaceApplication? {
        guard let selectedApplicationID else { return nil }
        return applications.first { $0.id == selectedApplicationID }
    }

    var hasSelectedApplication: Bool {
        selectedApplication != nil
    }

    func clearLog() {
        logEntries = []
    }

    func selectApplication(id: UUID) {
        selectedApplicationID = id
        syncOptions(from: id)
    }

    func addApplication() async {
        guard !isRunning else { return }

        applicationSelectionError = nil

        do {
            guard var application = try await applicationSelector.selectApplication() else {
                return
            }
            applyCurrentOptions(to: &application)
            applications.append(application)
            selectedApplicationID = application.id
            appendLog(
                "Added app \(application.displayName) "
                    + "(layout: \(application.windowLayout.rawValue), "
                    + "newInstance: \(application.createsNewApplicationInstance))"
            )
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
        if selectedApplicationID == id {
            selectedApplicationID = applications.first?.id
            if let selectedApplicationID {
                syncOptions(from: selectedApplicationID)
            }
        }
    }

    func applyCurrentOptionsToSelectedApplication() {
        guard let selectedApplicationID,
            let index = applications.firstIndex(where: { $0.id == selectedApplicationID })
        else {
            return
        }

        applyCurrentOptions(to: &applications[index])
    }

    func applyCurrentOptionsToAllApplications() {
        guard !applications.isEmpty else { return }

        for index in applications.indices {
            applyCurrentOptions(to: &applications[index])
        }
        appendLog("Applied application options to \(applications.count) app(s)")
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

    private func applyCurrentOptions(to application: inout WorkspaceApplication) {
        application.allowsRunningApplicationSubstitution = allowsRunningApplicationSubstitution
        application.createsNewApplicationInstance = createsNewApplicationInstance
        application.arguments = Self.parseArguments(argumentsText)
        application.environment = Self.parseEnvironment(environmentText)
        application.promptsUserIfNeeded = promptsUserIfNeeded
        application.windowLayout = windowLayout
    }

    private func syncOptions(from id: UUID) {
        guard let application = applications.first(where: { $0.id == id }) else { return }

        allowsRunningApplicationSubstitution = application.allowsRunningApplicationSubstitution
        createsNewApplicationInstance = application.createsNewApplicationInstance
        argumentsText = application.arguments.joined(separator: " ")
        environmentText = Self.formatEnvironment(application.environment)
        promptsUserIfNeeded = application.promptsUserIfNeeded
        windowLayout = application.windowLayout
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func appendLog(_ message: String) {
        logEntries.append("[\(Self.timestamp())] \(message)")
    }

    private static func parseArguments(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private static func parseEnvironment(_ text: String) -> [String: String] {
        var environment: [String: String] = [:]

        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let separator = trimmed.firstIndex(of: "=") else {
                continue
            }

            let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(trimmed[trimmed.index(after: separator)...])
            guard !key.isEmpty else { continue }
            environment[key] = value
        }

        return environment
    }

    private static func formatEnvironment(_ environment: [String: String]) -> String {
        environment.keys.sorted().map { key in
            "\(key)=\(environment[key] ?? "")"
        }
        .joined(separator: "\n")
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

#endif
