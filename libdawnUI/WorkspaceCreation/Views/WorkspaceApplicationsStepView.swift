//
//  WorkspaceApplicationsStepView.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

import Foundation
import SwiftUI

struct WorkspaceApplicationsStepView: View {
    let applications: [WorkspaceCreationApplicationItem]
    let isLoadingApplications: Bool

    @Binding var selectedApplicationIDs: [UUID]

    let confirmTitle: String
    let onChooseApplication: () -> Void
    let onNext: () -> Void

    @State private var searchQuery = ""

    private var filteredApplications: [WorkspaceCreationApplicationItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return applications
        }

        return applications.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedApplications: [WorkspaceCreationApplicationItem] {
        selectedApplicationIDs.compactMap { selectedID in
            applications.first {
                $0.id == selectedID
            }
        }
    }

    var body: some View {
        VStack {
            (Text("Choose ")

                + Text("apps")
                .foregroundStyle(DawnColors.emphasizedBody)

                + Text(" to open"))
                .font(DawnTextStyle.screenTitle)

            selectionSummary
            searchBar
            applicationGrid

            Spacer()

            DButton(action: onNext) {
                Text(confirmTitle)
                    .font(DawnFont.zain(.bold, size: DawnTextStyle.bodySize, relativeTo: .body))
                    .foregroundStyle(DawnColors.selectionForeground)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var selectionSummary: some View {
        VStack(spacing: 7) {
            if selectedApplications.isEmpty {
                Text("0 apps selected")
                    .font(DawnTextStyle.body)
                    .foregroundColor(DawnColors.menuItemSecondaryForeground)
            } else {
                HStack(spacing: -12) {
                    ForEach(selectedApplications.prefix(4)) { application in
                        selectedApplicationButton(application)
                    }

                    if selectedApplications.count > 4 {
                        Text(remainingApplicationsLabel)
                            .font(DawnTextStyle.caption)
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .frame(
            height: 50,
            alignment: .top
        )
        .accessibilityLabel(selectionSummaryText)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DawnColors.menuItemSecondaryForeground)

                TextField("App", text: $searchQuery)
                    .textFieldStyle(.plain)

                if !searchQuery.isEmpty {
                    DButton(
                        style: .compactIcon,
                        action: {
                            searchQuery = ""
                        },
                        content: {
                            Image(systemName: "xmark")
                        }
                    )
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(10)
            .background(DawnColors.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 7))

            DButton(style: .icon, action: onChooseApplication) {
                Image(systemName: "folder.badge.plus")
                    .frame(width: 24, height: 24)
            }
            .accessibilityLabel("Choose an application")
        }
    }

    @ViewBuilder
    private var applicationGrid: some View {
        if isLoadingApplications {
            ProgressView("Loading applications...")
                .frame(maxWidth: .infinity, minHeight: 220)
        } else if filteredApplications.isEmpty {
            ContentUnavailableView(
                searchQuery.isEmpty ? "No Applications Available" : "No Matching Applications",
                systemImage: "app.dashed"
            )
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            ScrollView {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 8),
                        count: 4
                    ),
                    spacing: 12
                ) {
                    ForEach(filteredApplications) { application in
                        applicationButton(application)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func applicationButton(_ application: WorkspaceCreationApplicationItem) -> some View {
        let isSelected = selectedApplicationIDs.contains(application.id)

        return DButton(
            style: .plain,
            action: {
                toggleSelection(of: application.id)
            },
            content: {
                VStack(spacing: 3) {
                    Image(nsImage: application.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 43, height: 43)

                    Text(application.name)
                        .font(DawnTextStyle.secondaryCaption)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .grayscale(isSelected ? 0 : 1)
                .opacity(isSelected ? 1 : 0.5)
            }
        )
        .accessibilityLabel(application.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectedApplicationButton(_ application: WorkspaceCreationApplicationItem) -> some View {
        DButton(
            style: .plain,
            action: {
                selectedApplicationIDs.removeAll {
                    $0 == application.id
                }
            },
            content: {
                Image(nsImage: application.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
            }
        )
        .help("Remove \(application.name)")
        .accessibilityLabel("Remove \(application.name) from selected applications")
    }

    private var selectionSummaryText: String {
        let count = selectedApplications.count
        let noun = count == 1 ? "app" : "apps"

        return "\(count) \(noun) selected"
    }

    private var remainingApplicationsLabel: String {
        let count = selectedApplications.count - 4
        let noun = count == 1 ? "app" : "apps"

        return "+\(count) \(noun)"
    }

    private func toggleSelection(of applicationID: UUID) {
        if let index = selectedApplicationIDs.firstIndex(of: applicationID) {
            selectedApplicationIDs.remove(at: index)
        } else {
            selectedApplicationIDs.append(applicationID)
        }
    }
}
