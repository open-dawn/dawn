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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Workspace transition lab", systemImage: "ladybug")
                .font(.title2)

            Text(
                "Configure activation policy, terminal command, and apps, "
                    + "then run a one-shot transition against dawnAgent."
            )
            .foregroundStyle(.secondary)
        }
    }

    private var connectionSection: some View {
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

    private var transitionSection: some View {
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

    private var appsSection: some View {
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
                Text("No apps — transition will only apply policy / focus / terminal.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.applications) { application in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(application.displayName)
                            Text(application.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Remove", role: .destructive) {
                            viewModel.removeApplication(id: application.id)
                        }
                        .disabled(viewModel.isRunning)
                    }
                }
            }

            if let error = viewModel.applicationSelectionError {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
            }
        }
    }

    private var existingContextSection: some View {
        Section("Existing context") {
            if contextStore.contexts.isEmpty {
                Text("No saved contexts")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Context", selection: $viewModel.selectedExistingContextID) {
                    Text("None").tag(Optional<UUID>.none)
                    ForEach(contextStore.contexts) { context in
                        Text(context.name).tag(Optional(context.id))
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
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

    private var logSection: some View {
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

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#endif
