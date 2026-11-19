//
//  ContextCreationConfirmationView.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/10/26.
//

import AppKit
import SwiftUI
import libdawn

struct ContextCreationConfirmationView: View {
    let name: String
    let symbolName: String
    let applications: [ContextCreationApplication]
    let activationPolicy: WorkspaceActivationPolicy
    let onFinishAndSwitch: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            confirmationHeader
            workspaceSummary

            Spacer()

            actionButtons
        }
    }

    private var confirmationHeader: some View {
        VStack(spacing: 0) {
            Text("Congrats!")
                .font(DawnTextStyle.confirmationTitle)
                .foregroundStyle(DawnColors.primaryForeground)

            (
                Text("Your workspace has been ")
                    .foregroundColor(DawnColors.menuItemSecondaryForeground)
                + Text("created")
                    .font(DawnTextStyle.emphasizedBody)
                    .foregroundColor(DawnColors.emphasizedBody)
            )
            .font(DawnTextStyle.body)
            .multilineTextAlignment(.center)
        }
    }

    private var workspaceSummary: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .font(.system(size: 36))
                .foregroundStyle(DawnColors.contextCardContent)
                .frame(width: 76, height: 76)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(name)
                        .font(DawnTextStyle.confirmationWorkspaceTitle)
                        .foregroundStyle(DawnColors.contextCardContent)
                        .lineLimit(1)
                        .layoutPriority(1)

                    Spacer(minLength: 0)

                    Label(
                        activationPolicy.displayName,
                        systemImage: activationPolicy.displaySymbol
                    )
                    .font(DawnTextStyle.contextMetadata)
                    .foregroundStyle(DawnColors.menuItemSecondaryForeground)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                }

                applicationSummary
            }
            .padding(.trailing, 10)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 92)
        .background(
            DawnColors.contextCardBackground,
            in: RoundedRectangle(cornerRadius: 9)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var applicationSummary: some View {
        if applications.isEmpty {
            Text("No apps")
                .font(DawnTextStyle.contextMetadata)
                .foregroundStyle(DawnColors.menuItemSecondaryForeground)
        } else {
            HStack(spacing: 8) {
                HStack(spacing: -10) {
                    ForEach(applications.prefix(3)) { application in
                        Image(nsImage: icon(for: application))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 27, height: 27)
                            .accessibilityLabel(application.displayName)
                    }
                }

                if remainingApplicationCount > 0 {
                    Text(
                        "+\(remainingApplicationCount) "
                        + (remainingApplicationCount == 1 ? "app" : "apps")
                    )
                    .font(DawnTextStyle.contextMetadata)
                    .foregroundStyle(DawnColors.menuItemSecondaryForeground)
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            DButton(style: .plain, action: onFinishAndSwitch) {
                Label("Start workspace", systemImage: "play.fill")
                    .font(DawnTextStyle.confirmationAction)
                    .frame(maxWidth: .infinity, minHeight: 32)
            }

            DButton(style: .primary, action: onFinish) {
                Text("Finish")
                    .font(DawnTextStyle.confirmationAction)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var remainingApplicationCount: Int {
        max(applications.count - 3, 0)
    }

    private func icon(for application: ContextCreationApplication) -> NSImage {
        guard let applicationURL = application.applicationURL else {
            return fallbackApplicationIcon
        }

        return NSWorkspace.shared.icon(
            forFile: applicationURL.path(percentEncoded: false)
        )
    }

    private var fallbackApplicationIcon: NSImage {
        NSImage(
            systemSymbolName: "app.dashed",
            accessibilityDescription: "Application"
        ) ?? NSImage(size: NSSize(width: 27, height: 27))
    }
}
