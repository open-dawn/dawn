//
//  ContextCard.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/10/26.
//

import AppKit
import SwiftUI

public enum ContextCardAction: Sendable {
    case activate
    case stop
    case openInApp
    case delete
}

public struct ContextCard: View {
    private let model: ContextCardModel
    private let isLoading: Bool
    private let onSelect: () -> Void
    private let onAction: (ContextCardAction) -> Void

    @State private var isHovering = false

    private static let maximumVisibleApplications = 3

    private var visibleApplications: ArraySlice<ContextCardModel.Application> {
        model.applications.prefix(Self.maximumVisibleApplications)
    }

    private var remainingApplicationCount: Int {
        max(model.applications.count - visibleApplications.count, 0)
    }

    public init(
        model: ContextCardModel,
        isLoading: Bool = false,
        onSelect: @escaping () -> Void = {},
        onAction: @escaping (ContextCardAction) -> Void = { _ in },
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
                    contextSymbol

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(model.name)
                                .font(DawnTextStyle.contextTitle)
                                .lineLimit(1)

                            Spacer()

                            trailingControl
                                .frame(width: 24)

                        }

                        statusContent

                        if !isActive {
                            applicationContent
                        }
                    }

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
                .fill(
                    isHovering ? DawnColors.contextCardHoveredBackground : DawnColors.contextCardBackground
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(
                    isHovering ? DawnColors.contextCardHoveredBorder : DawnColors.contextCardBorder
                )
        }
        .onHover {
            isHovering = $0
        }
    }

    @ViewBuilder
    private var contextSymbol: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image = NSImage(
                systemSymbolName: model.symbolName,
                accessibilityDescription: model.name
            ) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
            } else {
                Image(systemName: "square.dashed")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.secondary)
            }

            if isActive {
                Circle()
                    .fill(.green)
                    .frame(width: 9, height: 9)
                    .overlay {
                        Circle()
                            .stroke(Color.black, lineWidth: 1)
                    }
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 44, height: 44)
    }

    @ViewBuilder
    private var statusContent: some View {
        switch model.status {
        case .active(let activityText):
            Label(activityText, systemImage: "clock.fill")
                .font(DawnTextStyle.contextMetadata)
                .foregroundStyle(.secondary)

            Text("Currently active")
                .font(DawnTextStyle.contextMetadata)
                .foregroundStyle(.secondary)

        case .inactive(let lastUsedText):
            if let lastUsedText {
                Label(lastUsedText, systemImage: "clock.fill")
                    .font(DawnTextStyle.contextMetadata)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var applicationContent: some View {
        if model.applications.isEmpty {
            Text("No apps")
                .font(DawnTextStyle.contextMetadata)
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 6) {
                HStack(spacing: -5) {
                    ForEach(visibleApplications) { application in
                        Image(nsImage: application.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .background {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.black.opacity(0.25))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.black.opacity(0.5), lineWidth: 1)
                            }
                            .accessibilityHidden(true)
                    }
                }

                if remainingApplicationCount > 0 {
                    Text(remainingApplicationsLabel)
                        .font(DawnTextStyle.contextMetadata)
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
                .accessibilityLabel("Loading context")
        } else {
            Menu {
                switch model.status {
                case .active(let activityText):
                    Button {
                        onAction(.stop)
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .labelStyle(.titleAndIcon)
                    }
                case .inactive(let lastUsedText):
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
                    .foregroundStyle(.primary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Context actions")
        }
    }

    private var isActive: Bool {
        if case .active = model.status {
            return true
        }

        return false
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
