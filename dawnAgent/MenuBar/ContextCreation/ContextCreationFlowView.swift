//
//  ContextCreationFlowView.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

import SwiftUI

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
                    Button(action: goBack) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")

                    Spacer()

                    Button(action: onExit) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel context creation")
                }

                brand
            }
        }
    }

    private var brand: some View {
        HStack(spacing: 4) {
            Image(systemName: "sun.horizon")
            Text("dawn")
        }
        .font(.system(size: 20))
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
                    // TODO: Connect the system application picker
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
                    // TODO: Persist and activate the context
                    onExit()
                },
                onFinish: {
                    // TODO: Persist the context and return to root
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
