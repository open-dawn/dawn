//
//  ContextApplicationsStepView.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

import Foundation
import SwiftUI

struct ContextApplicationsStepView: View {
    let applications: [ContextCreationApplication]

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
                .font(.system(size: 21, weight: .bold))

            selectionSummary
            searchBar
            applicationGrid

            Button(action: onNext) {
                Text("Next")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
        }
    }

    private var selectionSummary: some View {
        VStack(spacing: 7) {
            Text(selectionSummaryText)
                .font(.system(size: 14))

            if !selectedApplications.isEmpty {
                HStack(spacing: -12) {
                    ForEach(selectedApplications.prefix(4)) { application in
                        selectedApplicationButton(application)
                    }

                    if selectedApplications.count > 4 {
                        Text("+\(selectedApplications.count - 4)")
                            .font(.system(size: 11))
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .accessibilityLabel(selectionSummaryText)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("App", text: $searchQuery)
                    .textFieldStyle(.plain)

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 7))

            Button(action: onChooseApplication) {
                Image(systemName: "folder.badge.plus")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose an application")
        }
    }

    @ViewBuilder
    private var applicationGrid: some View {
        if filteredApplications.isEmpty {
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

        return Button {
            toggleSelection(of: application.id)
        } label: {
            VStack(spacing: 3) {
                Image(nsImage: application.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 43, height: 43)

                Text(application.name)
                    .font(.system(size: 11, weight: .light))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .grayscale(isSelected ? 0 : 1)
            .opacity(isSelected ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(application.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectedApplicationButton(_ application: ContextCreationApplication) -> some View {
        Button {
            selectedApplicationIDs.removeAll {
                $0 == application.id
            }
        } label: {
            Image(nsImage: application.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
