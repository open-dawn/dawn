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
        var selectedExistingWorkspaceID: UUID?
        var selectedApplicationID: UUID?

        var allowsRunningApplicationSubstitution = true
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
                        + "(layout: \(application.windowLayout.rawValue))"
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

        func runEphemeralTransition(using store: SettingsWorkspaceStore) async {
            guard !isRunning else { return }
            isRunning = true
            defer { isRunning = false }

            let transition = transitionPreview
            let name = "Debug Transition \(Self.timestamp())"
            let symbol = "ladybug"

            appendLog("Starting ephemeral transition (\(transition.activationPolicy.rawValue))…")

            do {
                let workspaceID = try await store.createWorkspace(
                    name: name,
                    symbol: symbol,
                    applications: applications,
                    transition: transition
                )
                appendLog(
                    "Created workspace \(workspaceID.uuidString) — terminal: \(transition.terminalCommand ?? "nil")"
                )

                try await store.switchWorkspace(id: workspaceID)
                appendLog("Switch acknowledged — agent should be applying the transition")

                if cleanupAfterRun {
                    try await store.deleteWorkspace(id: workspaceID)
                    appendLog("Cleaned up ephemeral workspace")
                } else {
                    appendLog("Left workspace in store: \(name)")
                }

                await store.refresh()
                appendLog("Done")
            } catch {
                appendLog("FAILED: \(error.localizedDescription)")
            }
        }

        func runExistingWorkspace(using store: SettingsWorkspaceStore) async {
            guard !isRunning else { return }
            guard let selectedExistingWorkspaceID else {
                appendLog("Pick an existing workspace first")
                return
            }

            isRunning = true
            defer { isRunning = false }

            let name = store.workspaces.first { $0.id == selectedExistingWorkspaceID }?.name
                ?? selectedExistingWorkspaceID.uuidString
            appendLog("Switching existing workspace “\(name)”…")

            do {
                try await store.switchWorkspace(id: selectedExistingWorkspaceID)
                appendLog("Switch acknowledged")
            } catch {
                appendLog("FAILED: \(error.localizedDescription)")
            }
        }

        func applyTransitionToExistingWorkspace(using store: SettingsWorkspaceStore) async {
            guard !isRunning else { return }
            guard let selectedExistingWorkspaceID,
                  var workspace = store.workspaces.first(where: { $0.id == selectedExistingWorkspaceID })
            else {
                appendLog("Pick an existing workspace first")
                return
            }

            isRunning = true
            defer { isRunning = false }

            workspace.applications = applications
            workspace.transition = transitionPreview
            appendLog("Updating “\(workspace.name)” with current debug transition…")

            do {
                try await store.updateWorkspace(workspace)
                appendLog("Workspace updated")
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

        func refreshWorkspaces(using store: SettingsWorkspaceStore) async {
            appendLog("Refreshing workspaces…")
            await store.refresh()
            appendLog("Workspaces loaded: \(store.workspaces.count)")
        }

        private func applyCurrentOptions(to application: inout WorkspaceApplication) {
            application.allowsRunningApplicationSubstitution = allowsRunningApplicationSubstitution
            application.arguments = Self.parseArguments(argumentsText)
            application.environment = Self.parseEnvironment(environmentText)
            application.promptsUserIfNeeded = promptsUserIfNeeded
            application.windowLayout = windowLayout
        }

        private func syncOptions(from id: UUID) {
            guard let application = applications.first(where: { $0.id == id }) else { return }

            allowsRunningApplicationSubstitution = application.allowsRunningApplicationSubstitution
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
