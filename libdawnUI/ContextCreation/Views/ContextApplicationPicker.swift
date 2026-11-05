//
//  ContextApplicationPicker.swift
//  dawn
//
//  Created by Longhi on 05/11/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct ContextApplicationPicker: View {
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

    private let loadApplications: @MainActor () async throws -> [ContextCreationApplication]
    private let initialSelection: [ContextCreationApplication]
    private let confirmTitle: String
    private let onConfirm: @MainActor ([ContextCreationApplication]) -> Void
    private let onCancel: (@MainActor () -> Void)?
    private let onSelectionChange: @MainActor ([ContextCreationApplication]) -> Void
    private let onModalPresentationChange: @MainActor (ContextCreationModal, Bool) -> Void

    @State private var applications: [ContextCreationApplicationItem] = []
    @State private var selectedApplicationIDs: [UUID] = []
    @State private var isApplicationImporterPresented = false
    @State private var isLoadingApplications = false
    @State private var didLoadApplications = false
    @State private var importError: String?

    public init(
        loadApplications: @escaping @MainActor () async throws -> [ContextCreationApplication],
        initialSelection: [ContextCreationApplication] = [],
        confirmTitle: String,
        onConfirm: @escaping @MainActor ([ContextCreationApplication]) -> Void,
        onCancel: (@MainActor () -> Void)? = nil,
        onSelectionChange: @escaping @MainActor ([ContextCreationApplication]) -> Void = { _ in },
        onModalPresentationChange: @escaping @MainActor (
            ContextCreationModal,
            Bool
        ) -> Void = { _, _ in }
    ) {
        self.loadApplications = loadApplications
        self.initialSelection = initialSelection
        self.confirmTitle = confirmTitle
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.onSelectionChange = onSelectionChange
        self.onModalPresentationChange = onModalPresentationChange
    }

    private var isShowingImportError: Binding<Bool> {
        Binding(
            get: { importError != nil },
            set: { isPresented in
                if !isPresented {
                    importError = nil
                }
            }
        )
    }

    private var selection: Binding<[UUID]> {
        Binding(
            get: { selectedApplicationIDs },
            set: { newIDs in
                selectedApplicationIDs = newIDs
                reportSelection()
            }
        )
    }

    public var body: some View {
        ContextApplicationsStepView(
            applications: applications,
            isLoadingApplications: isLoadingApplications,
            selectedApplicationIDs: selection,
            confirmTitle: confirmTitle,
            onChooseApplication: {
                isApplicationImporterPresented = true
            },
            onNext: {
                onConfirm(selectedApplications())
            }
        )
        .overlay(alignment: .topTrailing) {
            if let onCancel {
                DButton(style: .compactIcon, action: onCancel) {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Close")
            }
        }
        .alert("Couldn't Add Application", isPresented: isShowingImportError) {
            Button("OK", role: .cancel) {
                importError = nil
            }
        } message: {
            Text(importError ?? "")
        }
        .fileImporter(
            isPresented: $isApplicationImporterPresented,
            allowedContentTypes: [.applicationBundle]
        ) { result in
            handleApplicationSelection(result)
        }
        .onChange(of: importError != nil) { _, isPresented in
            onModalPresentationChange(.operationError, isPresented)
        }
        .onChange(of: isApplicationImporterPresented) { _, isPresented in
            onModalPresentationChange(.applicationImporter, isPresented)
        }
        .onDisappear {
            onModalPresentationChange(.operationError, false)
            onModalPresentationChange(.applicationImporter, false)
        }
        .task {
            await loadInstalledApplications()
        }
    }
}

extension ContextApplicationPicker {
    private func loadInstalledApplications() async {
        guard !didLoadApplications, !isLoadingApplications else {
            return
        }

        didLoadApplications = true
        isLoadingApplications = true
        defer { isLoadingApplications = false }

        let preserved = initialSelection

        do {
            let installedApplications = try await loadApplications()
            guard !Task.isCancelled else {
                return
            }
            applications = catalog(installed: installedApplications, preserved: preserved)
        } catch {
            guard !Task.isCancelled else {
                return
            }
            importError = error.localizedDescription
            applications = preserved.map { application in
                makeItem(application)
            }
        }

        selectedApplicationIDs = preserved.compactMap { application in
            applications.first {
                $0.application.bundleIdentifier == application.bundleIdentifier
            }?.id
        }
        reportSelection()
    }

    private func handleApplicationSelection(_ result: Result<URL, Error>) {
        do {
            let applicationURL = try result.get()
            try addApplication(at: applicationURL)
        } catch CocoaError.userCancelled {
            return
        } catch {
            importError = error.localizedDescription
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
            bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? applicationURL.deletingPathExtension().lastPathComponent

        let application = ContextCreationApplication(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            applicationURL: applicationURL
        )

        let item = makeItem(application)
        applications.append(item)
        selectApplicationIfNeeded(item.id)
    }

    private func selectApplicationIfNeeded(_ applicationID: UUID) {
        guard !selectedApplicationIDs.contains(applicationID) else {
            return
        }

        selectedApplicationIDs.append(applicationID)
        reportSelection()
    }

    private func catalog(
        installed: [ContextCreationApplication],
        preserved: [ContextCreationApplication]
    ) -> [ContextCreationApplicationItem] {
        var items: [ContextCreationApplicationItem] = []
        var seenBundleIdentifiers = Set<String>()

        for application in installed + preserved {
            guard seenBundleIdentifiers.insert(application.bundleIdentifier).inserted else {
                continue
            }

            items.append(makeItem(application))
        }

        return items
    }

    private func makeItem(
        _ application: ContextCreationApplication
    ) -> ContextCreationApplicationItem {
        let icon: NSImage
        if let applicationURL = application.applicationURL {
            icon = NSWorkspace.shared.icon(
                forFile: applicationURL.path(percentEncoded: false)
            )
        } else {
            icon = NSImage(
                systemSymbolName: "app.dashed",
                accessibilityDescription: application.displayName
            ) ?? NSImage(size: NSSize(width: 43, height: 43))
        }

        return ContextCreationApplicationItem(
            application: application,
            icon: icon
        )
    }

    private func selectedApplications() -> [ContextCreationApplication] {
        selectedApplicationIDs.compactMap { selectedID in
            applications.first {
                $0.id == selectedID
            }?.application
        }
    }

    private func reportSelection() {
        onSelectionChange(selectedApplications())
    }
}
