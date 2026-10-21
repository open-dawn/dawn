//
//  ContextCreationConfirmationView.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/10/26.
//

import SwiftUI

struct ContextCreationConfirmationView: View {
    let onFinishAndSwitch: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 42) {
            VStack(spacing: 6) {
                Text("Congrats!")
                    .font(.system(size: 21, weight: .bold))

                Text("Your workspace has been created!")
                    .font(.system(size: 14))
            }
            .multilineTextAlignment(.center)

            Text("🎉")
                .font(.system(size: 96))
                .frame(width: 118, height: 147)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                Button(action: onFinishAndSwitch) {
                    Text("Finish and switch")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: onFinish) {
                    Text("Finish")
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
    }
}
