//
//  ContextCreationFlowView.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

import SwiftUI
import libdawnUI

struct ContextCreationFlowView: View {
    private enum Step: Equatable {
        case identity
        case applications
        case openingBehaviour
        case confirmation
    }

    @State private var step: Step = .identity
    @State private var draft = ContextCreationDraft()

    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            header
            stepContent
        }
        .padding(16)
        .frame(width: 320)
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
                applications: [],
                selectedApplicationIDs: $draft.selectedApplicationIDs,
                onChooseApplication: {
                    // PIN-122: Connect the system application picker
                },
                onNext: {
                    step = .openingBehaviour
                }
            )
        case .openingBehaviour:
            ContextOpeningBehaviorStepView(
                selectedBehavior: $draft.openingBehaviour,
                onFinish: {
                    step = .confirmation
                }
            )
        case .confirmation:
            ContextCreationConfirmationView(
                onFinishAndSwitch: {
                    // PIN-122: Persist and activate the context
                    onExit()
                },
                onFinish: {
                    // PIN-122: Persist the context and return to root
                    onExit()
                }
            )
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
}
