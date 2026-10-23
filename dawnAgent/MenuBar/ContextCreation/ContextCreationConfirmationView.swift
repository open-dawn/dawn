//
//  ContextCreationConfirmationView.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/10/26.
//

import SwiftUI
import libdawnUI

struct ContextCreationConfirmationView: View {
    let onFinishAndSwitch: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 42) {
            ContextCreationStepHeader(
                title: "Congrats!",
                subtitle: "Your workspace has been created."
            )

            Text("🎉")
                .font(.system(size: 96))
                .frame(width: 118, height: 147)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                DButton(style: .primary,action: onFinishAndSwitch) {
                    Text("Finish and switch")
                        .frame(maxWidth: .infinity)
                }

                DButton(style: .secondary, action: onFinish) {
                    Text("Finish")
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
