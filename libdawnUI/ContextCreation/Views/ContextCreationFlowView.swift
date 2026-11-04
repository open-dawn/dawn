//
//  ContextCreationFlowView.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct ContextCreationFlowView: View {
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
    @State private var createdContextID: UUID?
    @State private var isPerformingOperation = false
    @State private var operationError: String?
    @State private var applications: [ContextCreationApplicationItem] = []
    @State private var isApplicationImporterPresented = false
    @State private var isLoadingApplications = false

    private let loadApplications: @MainActor () async throws -> [ContextCreationApplication]
    private let onCreate: @MainActor (ContextCreationRequest) async throws -> UUID
    private let onActivate: @MainActor (UUID) async throws -> Void
    private let onModalPresentationChange: @MainActor (ContextCreationModal, Bool) -> Void

    let onExit: @MainActor () -> Void

    public init(
        loadApplications: @escaping @MainActor () async throws -> [ContextCreationApplication],
        createContext: @escaping @MainActor (ContextCreationRequest) async throws -> UUID,
        activateContext: @escaping @MainActor (UUID) async throws -> Void,
        onExit: @escaping @MainActor () -> Void,
        onModalPresentationChange: @escaping @MainActor (
            ContextCreationModal,
            Bool
        ) -> Void = { _, _ in }
    ) {
        self.loadApplications = loadApplications
        self.onCreate = createContext
        self.onActivate = activateContext
        self.onExit = onExit
        self.onModalPresentationChange = onModalPresentationChange
    }

    private var isShowingOperationError: Binding<Bool> {
        Binding(
            get: {
                operationError != nil
            },
            set: { isPresented in
                if !isPresented {
                    operationError = nil
                }
            }
        )
    }

    private var selectedApplications: [ContextCreationApplication] {
        draft.selectedApplicationIDs.compactMap { selectedID in
            applications.first {
                $0.id == selectedID
            }?.application
        }
    }

    public var body: some View {
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
            allowedContentTypes: [.applicationBundle]
        ) { result in
            handleApplicationSelection(result)
        }
        .onChange(of: operationError != nil) { _, isPresented in
            onModalPresentationChange(.operationError, isPresented)
        }
        .onChange(of: isApplicationImporterPresented) { _, isPresented in
            onModalPresentationChange(.applicationImporter, isPresented)
        }
        .onDisappear {
            onModalPresentationChange(.operationError, false)
            onModalPresentationChange(.applicationImporter, false)
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

        let request = ContextCreationRequest(
            name: name,
            symbolName: symbol,
            applications: selectedApplications,
            openingBehavior: draft.openingBehaviour
        )

        isPerformingOperation = true
        operationError = nil

        Task {
            defer {
                isPerformingOperation = false
            }

            do {
                createdContextID = try await onCreate(request)
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
        guard !isPerformingOperation, let createdContextID else {
            return
        }

        isPerformingOperation = true
        operationError = nil

        Task {
            defer {
                isPerformingOperation = false
            }

            do {
                try await onActivate(createdContextID)
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

        let displayName =
            bundle.object(
                forInfoDictionaryKey: "CFBundleDisplayName"
            ) as? String ?? bundle.object(
                forInfoDictionaryKey: "CFBundleName"
            ) as? String ?? applicationURL.deletingPathExtension().lastPathComponent

        let application = ContextCreationApplication(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            applicationURL: applicationURL
        )

        guard let item = makeItem(application) else {
            throw ApplicationImportError.invalidApplication
        }

        applications.append(item)
        draft.selectedApplicationIDs.append(item.id)
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
            let installedApplications = try await loadApplications()

            let existingBundleIdentifiers = Set(
                applications.map {
                    $0.application.bundleIdentifier
                }
            )

            let newApplications = installedApplications.filter {
                !existingBundleIdentifiers.contains($0.bundleIdentifier)
            }.compactMap { application in
                makeItem(application)
            }

            applications.append(contentsOf: newApplications)
        } catch {
            operationError = error.localizedDescription
        }
    }

    private func makeItem(
        _ application: ContextCreationApplication
    ) -> ContextCreationApplicationItem? {
        guard let applicationURL = application.applicationURL else {
            return nil
        }

        return ContextCreationApplicationItem(
            application: application,
            icon: NSWorkspace.shared.icon(
                forFile: applicationURL.path(percentEncoded: false)
            )
        )
    }
}
