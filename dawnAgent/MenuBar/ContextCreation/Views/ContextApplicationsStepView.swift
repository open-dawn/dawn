//
//  ContextApplicationsStepView.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

import Foundation
import SwiftUI
import libdawnUI

struct ContextApplicationsStepView: View {
    let applications: [ContextCreationApplication]
    let isLoadingApplications: Bool

    @Binding var selectedApplicationIDs: [UUID]

    let onChooseApplication: () -> Void
    let onNext: () -> Void

    @State private var searchQuery = ""

    private var filteredApplications: [ContextCreationApplication] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return applications
        }

        return applications.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedApplications: [ContextCreationApplication] {
        selectedApplicationIDs.compactMap { selectedID in
            applications.first {
                $0.id == selectedID
            }
        }
    }

    var body: some View {
        VStack(spacing: 28) {
            Text("Choose your apps")
                .font(DawnTextStyle.screenTitle)

            selectionSummary
            searchBar
            applicationGrid

            Spacer()

            DButton(action: onNext) {
                Text("Next")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var selectionSummary: some View {
        VStack(spacing: 7) {
            Text(selectionSummaryText)
                .font(DawnTextStyle.body)

            if !selectedApplications.isEmpty {
                HStack(spacing: -12) {
                    ForEach(selectedApplications.prefix(4)) { application in
                        selectedApplicationButton(application)
                    }

                    if selectedApplications.count > 4 {
                        Text("+\(selectedApplications.count - 4)")
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
            .frame(height: 220)
        }
    }

    private func applicationButton(_ application: ContextCreationApplication) -> some View {
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

    private func selectedApplicationButton(_ application: ContextCreationApplication) -> some View {
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

    private func toggleSelection(of applicationID: UUID) {
        if let index = selectedApplicationIDs.firstIndex(of: applicationID) {
            selectedApplicationIDs.remove(at: index)
        } else {
            selectedApplicationIDs.append(applicationID)
        }
    }
}
