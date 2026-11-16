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

    private var isActive: Bool {
        if case .active = model.status {
            return true
        }

        return false
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

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center) {
                            Text(model.name)
                                .font(DawnTextStyle.contextTitle)
                                .foregroundStyle(
                                    isActive ? DawnColors.contextCardContentActive : DawnColors.contextCardContent
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
                    .frame(width: 46, height: 46)
                    .foregroundStyle(
                        isActive ? DawnColors.contextCardContentActive : DawnColors.contextCardContent
                    )
            } else {
                Image(systemName: "square.dashed")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(
                        isActive ? DawnColors.contextCardContentActive : DawnColors.contextCardContent
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
                .font(DawnTextStyle.contextMetadata)
                .foregroundStyle(DawnColors.contextCardContentActive)

        case .inactive(let lastUsedText):
            if let lastUsedText {
                HStack(spacing: 0) {
                    Spacer()

                    Group {
                        Label("Last use: ", systemImage: "clock")

                        Text(lastUsedText)
                            .bold()
                    }
                    .font(DawnTextStyle.contextMetadata)
                    .foregroundStyle(.secondary)
                }
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
            .foregroundStyle(isActive ? DawnColors.contextCardContentActive : DawnColors.contextCardContent)
            .fixedSize()
            .accessibilityLabel("Context actions")
        }
    }

    private var cardBackgroundColor: Color {
        return switch (isActive, isHovering) {
        case (true, true):
            DawnColors.selectedContextCardHoveredBackground

        case (true, false):
            DawnColors.selectedContextCardBackground

        case (false, true):
            DawnColors.contextCardHoveredBackground

        case (false, false):
            DawnColors.contextCardBackground
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
