//
//  ContextCreationFlowView.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

import AppKit
import UniformTypeIdentifiers
import SwiftUI
import libdawn
import libdawnUI

struct ContextCreationFlowView: View {
    private enum Step: Equatable {
        case identity
        case applications
        case openingBehaviour
        case confirmation
    }

    private enum ApplicationImportError: LocalizedError {
        case invalidApplication
        case missingBundleIdentifier

        var errorDescription: String? {
            switch self {
            case .invalidApplication:
                "The selected item is not a valid application."
            case .missingBundleIdentifier:
                "The selected application has no bundle identifier."
            }
        }
    }

    @State private var step: Step = .identity
    @State private var draft = ContextCreationDraft()
    @State private var createdContext: WorkspaceContext?
    @State private var isPerformingOperation = false
    @State private var operationError: String?
    @State private var applications: [ContextCreationApplication] = []
    @State private var isApplicationImporterPresented = false
    @State private var isLoadingApplications = false

    private let applicationProvider: any InstalledApplicationProviding

    let workspace: WorkspaceRuntime
    let onExit: () -> Void

    init(
        workspace: WorkspaceRuntime,
        applicationProvider: any InstalledApplicationProviding = ApplicationsDirectoryProvider(),
        onExit: @escaping () -> Void
    ) {
        self.workspace = workspace
        self.applicationProvider = applicationProvider
        self.onExit = onExit
    }

    private var isShowingOperationError: Binding<Bool> {
        Binding(get: {
            operationError != nil
        }, set: { isPresented in
            if !isPresented {
                operationError = nil
            }
        })
    }

    private var selectedApplications: [WorkspaceApplication] {
        draft.selectedApplicationIDs.compactMap { selectedID in
            applications.first {
                $0.id == selectedID
            }?.application
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            header
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(16)
        .frame(width: 320, height: 600)
        .alert("Couldn't Complete Context Creation", isPresented: isShowingOperationError) {
            Button("OK") {
                operationError = nil
            }
        } message: {
            Text(operationError ?? "")
        }
        .fileImporter(
            isPresented: $isApplicationImporterPresented,
            allowedContentTypes: [.applicationBundle]) { result in
                handleApplicationSelection(result)
            }
    }

    @ViewBuilder
    private var header: some View {
        if step == .confirmation {
            brand
        } else {
            ZStack {
                HStack {
                    DButton(
                        style: .compactIcon,
                        action: goBack
                    ) {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Back")

                    Spacer()

                    DButton(
                        style: .compactIcon,
                        action: onExit
                    ) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Cancel context creation")
                }

                brand
            }
            .task {
                await loadInstalledApplications()
            }
        }
    }

    private var brand: some View {
        DawnBrand(style: .compact)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .identity:
            VStack {
                ContextIdentityStepView(
                    name: $draft.name,
                    selectedSymbolName: $draft.symbolName,
                    onNext: {
                        step = .applications
                    }
                )
            }
        case .applications:
            ContextApplicationsStepView(
                applications: applications,
                isLoadingApplications: isLoadingApplications,
                selectedApplicationIDs: $draft.selectedApplicationIDs,
                onChooseApplication: {
                    isApplicationImporterPresented = true
                },
                onNext: {
                    step = .openingBehaviour
                }
            )
        case .openingBehaviour:
            ContextOpeningBehaviorStepView(
                selectedBehavior: $draft.openingBehaviour,
                onFinish: createContext
            )
        case .confirmation:
            ContextCreationConfirmationView(
                onFinishAndSwitch: finishAndSwitch,
                onFinish: onExit
            )
        }
    }
}

// MARK: methods

extension ContextCreationFlowView {
    private func createContext() {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !isPerformingOperation, !name.isEmpty, let symbol = draft.symbolName else {
            return
        }

        isPerformingOperation = true
        operationError = nil

        Task {
            defer {
                isPerformingOperation = false
            }

            do {
                let context = try await workspace.createContext(
                    name: name,
                    symbol: symbol,
                    applications: selectedApplications
                )

                createdContext = context
                step = .confirmation
            } catch {
                operationError = error.localizedDescription
            }
        }
    }

    private func goBack() {
        switch step {
        case .identity:
            onExit()
        case .applications:
            step = .identity
        case .openingBehaviour:
            step = .applications
        case .confirmation:
            step = .openingBehaviour
        }
    }

    private func finishAndSwitch() {
        guard !isPerformingOperation, let createdContext else {
            return
        }

        isPerformingOperation = true
        operationError = nil

        Task {
            defer {
                isPerformingOperation = false
            }

            do {
                try await workspace.activateContext(id: createdContext.id)

                onExit()
            } catch {
                operationError = error.localizedDescription
            }
        }
    }

    private func handleApplicationSelection(_ result: Result<URL, Error>) {
        do {
            let applicationURL = try result.get()
            try addApplication(at: applicationURL)
        } catch CocoaError.userCancelled {
            return
        } catch {
            operationError = error.localizedDescription
        }
    }

    private func addApplication(at applicationURL: URL) throws {
        guard let bundle = Bundle(url: applicationURL) else {
            throw ApplicationImportError.invalidApplication
        }

        guard let bundleIdentifier = bundle.bundleIdentifier else {
            throw ApplicationImportError.missingBundleIdentifier
        }

        if let existingApplication = applications.first(where: {
            $0.application.bundleIdentifier == bundleIdentifier
        }) {
            selectApplicationIfNeeded(existingApplication.id)
            return
        }

        let displayName = bundle.object(
            forInfoDictionaryKey: "CFBundleDisplayName"
        ) as? String ?? bundle.object(
            forInfoDictionaryKey: "CFBundleName"
        ) as? String ?? applicationURL.deletingPathExtension().lastPathComponent

        let workspaceApplication = WorkspaceApplication(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            applicationURL: applicationURL
        )

        let application = ContextCreationApplication(
            application: workspaceApplication,
            icon: NSWorkspace.shared.icon(forFile: applicationURL.path(percentEncoded: false))
        )

        applications.append(application)
        draft.selectedApplicationIDs.append(application.id)
    }

    private func selectApplicationIfNeeded(_ applicationID: UUID) {
        guard !draft.selectedApplicationIDs.contains(applicationID) else {
            return
        }

        draft.selectedApplicationIDs.append(applicationID)
    }

    private func loadInstalledApplications() async {
        guard !isLoadingApplications else {
            return
        }

        isLoadingApplications = true
        defer {
            isLoadingApplications = false
        }

        do {
            let installedApplications = try await applicationProvider.applications()

            let existingBundleIdentifiers = Set(applications.map {
                $0.application.bundleIdentifier
            })

            let newApplications = installedApplications.filter {
                !existingBundleIdentifiers.contains($0.bundleIdentifier)
            } .compactMap { application -> ContextCreationApplication? in
                guard let applicationURL = application.applicationURL else {
                    return nil
                }

                return ContextCreationApplication(
                    application: application,
                    icon: NSWorkspace.shared.icon(
                        forFile: applicationURL.path(percentEncoded: false)
                    )
                )
            }

            applications.append(contentsOf: newApplications)
        } catch {
            operationError = error.localizedDescription
        }
    }
}
