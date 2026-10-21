//
//  ContextIdentityStepView.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

import Foundation
import SwiftUI

struct ContextIdentityStepView: View {
    private static let symbols = [
        "gamecontroller.fill",
        "network",
        "apple.logo",
        "playstation.logo",
        "shippingbox",
        "eraser",
        "scribble",
        "pencil.tip.crop.circle",
        "folder",
        "paperplane",
        "externaldrive",
        "document",
    ]

    @Binding var name: String
    @Binding var selectedSymbolName: String?

    let onNext: () -> Void

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedSymbolName != nil
    }

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 6) {
                Text("Name your workspace")
                    .font(.system(size: 21, weight: .bold))

                Text("Choose a name and symbol for your workspace.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 20) {
                nameField
                symbolPicker
            }

            // TODO: Update this button with shared asset when the asset it's merged on main
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
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.5)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Name")
                .font(.system(size: 14, weight: .light))

            TextField("Context name", text: $name)
                .textFieldStyle(.plain)
                .padding(11)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
    }

    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Symbol")
                .font(.system(size: 14, weight: .light))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)) {
                ForEach(Self.symbols, id: \.self) { symbolName in
                    symbolButton(symbolName)
                }
            }
        }
    }

    private func symbolButton(_ symbolName: String) -> some View {
        let isSelected = selectedSymbolName == symbolName

        return Button {
            selectedSymbolName = symbolName
        } label: {
            Image(systemName: symbolName)
                .font(.system(size: 25))
                .foregroundStyle(isSelected ? .black : .white)
                .frame(maxWidth: .infinity, minHeight: 53)
                .background(isSelected ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbolName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
