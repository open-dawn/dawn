//
//  WorkspaceCard.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/10/26.
//

import AppKit
import SwiftUI

public enum WorkspaceCardAction: Sendable {
    case activate
    case stop
    case openInApp
    case delete
}

public struct WorkspaceCard: View {
    private let model: WorkspaceCardModel
    private let isLoading: Bool
    private let onSelect: () -> Void
    private let onAction: (WorkspaceCardAction) -> Void

    @State private var isHovering = false

    private static let maximumVisibleApplications = 3

    private var visibleApplications: ArraySlice<WorkspaceCardModel.Application> {
        model.applications.prefix(Self.maximumVisibleApplications)
    }

    private var remainingApplicationCount: Int {
        max(model.applications.count - visibleApplications.count, 0)
    }

    private var isActive: Bool {
        if case .active = model.status {
            return true
        }

        return false
    }

    public init(
        model: WorkspaceCardModel,
        isLoading: Bool = false,
        onSelect: @escaping () -> Void = {},
        onAction: @escaping (WorkspaceCardAction) -> Void = { _ in },
    ) {
        self.model = model
        self.isLoading = isLoading
        self.onSelect = onSelect
        self.onAction = onAction
    }

    public var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    workspaceSymbol

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center) {
                            Text(model.name)
                                .font(DawnTextStyle.workspaceTitle)
                                .foregroundStyle(
                                    isActive ? DawnColors.workspaceCardContentActive : DawnColors.workspaceCardContent
                                )
                                .lineLimit(1)

                            Spacer()

                            VStack {
                                trailingControl
                                    .frame(height: 6)

                                Spacer()
                            }
                        }

                        HStack {
                            if !isActive {
                                applicationContent
                            }

                            statusContent
                        }
                    }
                    .frame(height: 12)

                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .accessibilityLabel(model.name)
            .accessibilityValue(statusAccessibilityValue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(minHeight: 80)
        .background {
            RoundedRectangle(cornerRadius: 9)
                .fill(cardBackgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(
                    isHovering ? DawnColors.workspaceCardHoveredBorder : DawnColors.workspaceCardBorder
                )
        }
        .onHover {
            isHovering = $0
        }
    }

    @ViewBuilder
    private var workspaceSymbol: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image = NSImage(
                systemSymbolName: model.symbolName,
                accessibilityDescription: model.name
            ) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .foregroundStyle(
                        isActive ? DawnColors.workspaceCardContentActive : DawnColors.workspaceCardContent
                    )
            } else {
                Image(systemName: "square.dashed")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(
                        isActive ? DawnColors.workspaceCardContentActive : DawnColors.workspaceCardContent
                    )
            }
        }
        .frame(width: 44, height: 44)
    }

    @ViewBuilder
    private var statusContent: some View {
        switch model.status {
        case .active(let activityText):
            Label(activityText, systemImage: "clock")
                .font(DawnTextStyle.workspaceMetadata)
                .foregroundStyle(DawnColors.workspaceCardContentActive)

        case .inactive(let lastUsedText):
            if let lastUsedText {
                HStack(spacing: 0) {
                    Spacer()

                    Group {
                        Label("Last use: ", systemImage: "clock")

                        Text(lastUsedText)
                            .bold()
                    }
                    .font(DawnTextStyle.workspaceMetadata)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var applicationContent: some View {
        if model.applications.isEmpty {
            Text("No apps")
                .font(DawnTextStyle.workspaceMetadata)
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 6) {
                HStack(spacing: -5) {
                    ForEach(visibleApplications) { application in
                        Image(nsImage: application.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .accessibilityHidden(true)
                    }
                }

                if remainingApplicationCount > 0 {
                    Text(remainingApplicationsLabel)
                        .font(DawnTextStyle.workspaceMetadata)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 18)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(applicationsAccessibilityLabel)
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        if isLoading {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Loading workspace")
        } else {
            Menu {
                switch model.status {
                case .active:
                    Button {
                        onAction(.stop)
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .labelStyle(.titleAndIcon)
                    }
                case .inactive:
                    Button {
                        onAction(.activate)
                    } label: {
                        Label("Activate", systemImage: "play.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }

                Button {
                    onAction(.openInApp)
                } label: {
                    Label("Open in App", systemImage: "arrow.up.forward.app")
                        .labelStyle(.titleAndIcon)
                }

                Divider()

                Button(role: .destructive) {
                    onAction(.delete)
                } label: {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.titleAndIcon)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .foregroundStyle(isActive ? DawnColors.workspaceCardContentActive : DawnColors.workspaceCardContent)
            .fixedSize()
            .accessibilityLabel("Workspace actions")
        }
    }

    private var cardBackgroundColor: Color {
        return switch (isActive, isHovering) {
        case (true, true):
            DawnColors.selectedWorkspaceCardHoveredBackground

        case (true, false):
            DawnColors.selectedWorkspaceCardBackground

        case (false, true):
            DawnColors.workspaceCardHoveredBackground

        case (false, false):
            DawnColors.workspaceCardBackground
        }
    }

    private var statusAccessibilityValue: String {
        switch model.status {
        case .active(let activityText):
            "Currently active, \(activityText)"
        case .inactive(let lastUsedText):
            if let lastUsedText {
                "Last active \(lastUsedText)"
            } else {
                "Inactive"
            }
        }
    }

    private var remainingApplicationsLabel: String {
        let noun = remainingApplicationCount == 1 ? "app" : "apps"

        return "+\(remainingApplicationCount) \(noun)"
    }

    private var applicationsAccessibilityLabel: String {
        let names = model.applications.map(\.name).joined(separator: ", ")

        return "\(model.applications.count) applications: \(names)"
    }
}
