#if DEBUG

    import libdawn
    import SwiftUI

    struct WorkspaceTransitionDebugView: View {
        @Environment(SettingsContextStore.self) private var contextStore
        @Environment(SettingsEventBusService.self) private var eventBusService

        @State private var viewModel = WorkspaceTransitionDebugViewModel()

        private var interactionsDisabled: Bool {
            !eventBusService.isConnected || viewModel.isRunning
        }

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    Form {
                        connectionSection
                        transitionSection
                        appsSection
                        applicationSection
                        existingContextSection
                        actionsSection
                        logSection
                    }
                    .formStyle(.grouped)
                    .disabled(viewModel.isRunning)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Debug")
            .onChange(of: viewModel.allowsRunningApplicationSubstitution) { _, _ in
                viewModel.applyCurrentOptionsToSelectedApplication()
            }
            .onChange(of: viewModel.createsNewApplicationInstance) { _, _ in
                viewModel.applyCurrentOptionsToSelectedApplication()
            }
            .onChange(of: viewModel.argumentsText) { _, _ in
                viewModel.applyCurrentOptionsToSelectedApplication()
            }
            .onChange(of: viewModel.environmentText) { _, _ in
                viewModel.applyCurrentOptionsToSelectedApplication()
            }
            .onChange(of: viewModel.promptsUserIfNeeded) { _, _ in
                viewModel.applyCurrentOptionsToSelectedApplication()
            }
            .onChange(of: viewModel.windowLayout) { _, _ in
                viewModel.applyCurrentOptionsToSelectedApplication()
            }
        }
    }

    private extension WorkspaceTransitionDebugView {
        var header: some View {
            VStack(alignment: .leading, spacing: 4) {
                Label("Workspace transition lab", systemImage: "ladybug")
                    .font(.title2)

                Text(
                    "Configure activation policy, terminal command, application launch options, "
                        + "and apps, then run a one-shot transition against dawnAgent."
                )
                .foregroundStyle(.secondary)
            }
        }

        var connectionSection: some View {
            Section("Connection") {
                LabeledContent("Agent") {
                    Text(eventBusService.isConnected ? "Connected" : "Disconnected")
                        .foregroundStyle(eventBusService.isConnected ? .green : .orange)
                }

                LabeledContent("Contexts") {
                    Text("\(contextStore.contexts.count)")
                }
            }
        }

        var transitionSection: some View {
            Section("Transition") {
                Picker("Activation policy", selection: $viewModel.activationPolicy) {
                    Text("Hide others").tag(WorkspaceActivationPolicy.hide)
                    Text("Merge (open missing only)").tag(WorkspaceActivationPolicy.merge)
                    Text("Close others").tag(WorkspaceActivationPolicy.close)
                }

                TextField("Terminal command (optional)", text: $viewModel.terminalCommand)
                    .textFieldStyle(.roundedBorder)

                Toggle("Delete ephemeral context after run", isOn: $viewModel.cleanupAfterRun)
            }
        }

        var appsSection: some View {
            Section("Apps to open") {
                HStack {
                    Text("Apps (\(viewModel.applications.count))")
                    Spacer()
                    Button {
                        Task { await viewModel.addApplication() }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(interactionsDisabled)
                }

                if viewModel.applications.isEmpty {
                    Text("No apps — transition will only apply policy and settings")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.applications) { application in
                        appRow(application)
                    }
                }

                if let error = viewModel.applicationSelectionError {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                }
            }
        }

        var applicationSection: some View {
            Section {
                if let selected = viewModel.selectedApplication {
                    LabeledContent("Editing") {
                        Text(selected.displayName)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Defaults for newly added apps. Select an app above to edit it.")
                        .foregroundStyle(.secondary)
                }

                Toggle(
                    "Allow running application substitution",
                    isOn: $viewModel.allowsRunningApplicationSubstitution
                )

                Toggle(
                    "Create new application instance",
                    isOn: $viewModel.createsNewApplicationInstance
                )

                Toggle(
                    "Prompt user if needed",
                    isOn: $viewModel.promptsUserIfNeeded
                )

                Picker("Window layout", selection: $viewModel.windowLayout) {
                    ForEach(WorkspaceWindowLayout.allCases, id: \.self) { layout in
                        Text(layout.displayName).tag(layout)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Arguments")
                    TextField("e.g. --args hello", text: $viewModel.argumentsText)
                        .textFieldStyle(.roundedBorder)
                    Text("Whitespace-separated launch arguments")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Environment")
                    TextEditor(text: $viewModel.environmentText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 72)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.quaternary)
                        }
                    Text("One KEY=VALUE pair per line")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Apply options to all listed apps") {
                    viewModel.applyCurrentOptionsToAllApplications()
                }
                .disabled(viewModel.applications.isEmpty)
            } header: {
                Text("Application")
            } footer: {
                Text(
                    "These options map to WorkspaceApplication launch fields used by "
                        + "WMOpenAppAction and WMWindowLayoutAction."
                )
            }
        }

        var existingContextSection: some View {
            Section("Existing context") {
                if contextStore.contexts.isEmpty {
                    Text("No saved contexts")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Context", selection: $viewModel.selectedExistingContextID) {
                        Text("None").tag(UUID?.none)
                        ForEach(contextStore.contexts) { context in
                            Text(context.name).tag(Optional(context.id))
                        }
                    }
                }
            }
        }

        var actionsSection: some View {
            Section("Actions") {
                Button {
                    Task { await viewModel.runEphemeralTransition(using: contextStore) }
                } label: {
                    actionLabel("Run ephemeral transition", systemImage: "play.fill")
                }
                .disabled(interactionsDisabled)
                .help(
                    "Create a temporary context with this transition, switch to it, then optionally delete it"
                )

                Button {
                    Task { await viewModel.applyTransitionToExistingContext(using: contextStore) }
                } label: {
                    actionLabel("Apply config to selected context", systemImage: "square.and.pencil")
                }
                .disabled(interactionsDisabled || viewModel.selectedExistingContextID == nil)

                Button {
                    Task { await viewModel.runExistingContext(using: contextStore) }
                } label: {
                    actionLabel("Switch selected context", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(interactionsDisabled || viewModel.selectedExistingContextID == nil)

                Button {
                    Task { await viewModel.sendDebugPing(using: eventBusService) }
                } label: {
                    actionLabel("Send debug ping", systemImage: "antenna.radiowaves.left.and.right")
                }
                .disabled(interactionsDisabled)

                Button {
                    Task { await viewModel.refreshContexts(using: contextStore) }
                } label: {
                    actionLabel("Refresh contexts", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isRunning)

                if viewModel.isRunning {
                    ProgressView("Running…")
                        .controlSize(.small)
                }
            }
        }

        var logSection: some View {
            Section {
                if viewModel.logEntries.isEmpty {
                    Text("Action output will appear here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(viewModel.logEntries.enumerated()), id: \.offset) { _, entry in
                        Text(entry)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                Button("Clear log") {
                    viewModel.clearLog()
                }
                .disabled(viewModel.logEntries.isEmpty || viewModel.isRunning)
            } header: {
                Text("Log")
            }
        }

        func appRow(_ application: WorkspaceApplication) -> some View {
            let isSelected = viewModel.selectedApplicationID == application.id

            return HStack {
                Button {
                    viewModel.selectApplication(id: application.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(application.displayName)
                            Text(application.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(appOptionsSummary(application))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)

                Button("Remove", role: .destructive) {
                    viewModel.removeApplication(id: application.id)
                }
                .disabled(viewModel.isRunning)
            }
        }

        func appOptionsSummary(_ application: WorkspaceApplication) -> String {
            var parts = [
                "layout: \(application.windowLayout.rawValue)",
            ]

            if application.createsNewApplicationInstance {
                parts.append("new instance")
            }
            if !application.allowsRunningApplicationSubstitution {
                parts.append("no substitution")
            }
            if application.promptsUserIfNeeded {
                parts.append("prompt")
            }
            if !application.arguments.isEmpty {
                parts.append("args: \(application.arguments.count)")
            }
            if !application.environment.isEmpty {
                parts.append("env: \(application.environment.count)")
            }

            return parts.joined(separator: " · ")
        }

        func actionLabel(_ title: String, systemImage: String) -> some View {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private extension WorkspaceWindowLayout {
        var displayName: String {
            switch self {
            case .window: "Window"
            case .minimized: "Minimized"
            case .fullscreen: "Fullscreen"
            }
        }
    }

#endif
