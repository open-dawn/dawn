//
//  WorkspaceCreationFlowView.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

import SwiftUI

public struct WorkspaceCreationFlowView: View {
    private enum Step: Equatable {
        case identity
        case applications
        case openingBehaviour
        case confirmation
    }

    @State private var step: Step = .identity
    @State private var draft = WorkspaceCreationDraft()
    @State private var createdWorkspaceID: UUID?
    @State private var isPerformingOperation = false
    @State private var operationError: String?

    private let loadApplications: @MainActor () async throws -> [WorkspaceCreationApplication]
    private let onCreate: @MainActor (WorkspaceCreationRequest) async throws -> UUID
    private let onActivate: @MainActor (UUID) async throws -> Void
    private let onModalPresentationChange: @MainActor (WorkspaceCreationModal, Bool) -> Void

    let onExit: @MainActor () -> Void

    public init(
        loadApplications: @escaping @MainActor () async throws -> [WorkspaceCreationApplication],
        createWorkspace: @escaping @MainActor (WorkspaceCreationRequest) async throws -> UUID,
        activateWorkspace: @escaping @MainActor (UUID) async throws -> Void,
        onExit: @escaping @MainActor () -> Void,
        onModalPresentationChange: @escaping @MainActor (
            WorkspaceCreationModal,
            Bool
        ) -> Void = { _, _ in }
    ) {
        self.loadApplications = loadApplications
        self.onCreate = createWorkspace
        self.onActivate = activateWorkspace
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

    public var body: some View {
        VStack(spacing: 24) {
            header
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(16)
        .frame(width: 320, height: 600)
        .alert("Couldn't Complete Workspace Creation", isPresented: isShowingOperationError) {
            Button("OK") {
                operationError = nil
            }
        } message: {
            Text(operationError ?? "")
        }
        .onChange(of: operationError != nil) { _, isPresented in
            onModalPresentationChange(.operationError, isPresented)
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
                    .accessibilityLabel("Cancel workspace creation")
                }

                brand
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
            WorkspaceIdentityStepView(
                name: $draft.name,
                selectedSymbolName: $draft.symbolName,
                onNext: {
                    step = .applications
                }
            )
        case .applications:
            WorkspaceApplicationPicker(
                loadApplications: loadApplications,
                initialSelection: draft.selectedApplications,
                confirmTitle: "Next",
                onConfirm: { selected in
                    draft.selectedApplications = selected
                    step = .openingBehaviour
                },
                onSelectionChange: { selected in
                    draft.selectedApplications = selected
                },
                onModalPresentationChange: onModalPresentationChange
            )
        case .openingBehaviour:
            WorkspaceOpeningBehaviorStepView(
                selectedPolicy: $draft.activationPolicy,
                onFinish: createWorkspace
            )
        case .confirmation:
            WorkspaceCreationConfirmationView(
                name: draft.name,
                symbolName: draft.symbolName ?? "square.dashed",
                applications: draft.selectedApplications,
                activationPolicy: draft.activationPolicy,
                onFinishAndSwitch: finishAndSwitch,
                onFinish: onExit
            )
        }
    }
}

// MARK: methods

extension WorkspaceCreationFlowView {
    private func createWorkspace() {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !isPerformingOperation, !name.isEmpty, let symbol = draft.symbolName else {
            return
        }

        let request = WorkspaceCreationRequest(
            name: name,
            symbolName: symbol,
            applications: draft.selectedApplications,
            activationPolicy: draft.activationPolicy
        )

        isPerformingOperation = true
        operationError = nil

        Task {
            defer {
                isPerformingOperation = false
            }

            do {
                createdWorkspaceID = try await onCreate(request)
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
        guard !isPerformingOperation, let createdWorkspaceID else {
            return
        }

        isPerformingOperation = true
        operationError = nil

        Task {
            defer {
                isPerformingOperation = false
            }

            do {
                try await onActivate(createdWorkspaceID)
                onExit()
            } catch {
                operationError = error.localizedDescription
            }
        }
    }
}
