//
//  ContextIdentityStepView.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

import Foundation
import SwiftUI
import libdawnUI

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
            ContextCreationStepHeader(
                title: "Name your workspace",
                subtitle: "Choose a name and symbol for your workspace.",
            )

            VStack(alignment: .leading, spacing: 20) {
                nameField
                symbolPicker
            }

            DButton(action: onNext) {
                Text("Next")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.5)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Name")
                .font(DawnTextStyle.fieldLabel)

            TextField("Context name", text: $name)
                .textFieldStyle(.plain)
                .padding(11)
                .background(DawnColors.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
    }

    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Symbol")
                .font(DawnTextStyle.fieldLabel)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)) {
                ForEach(Self.symbols, id: \.self) { symbolName in
                    symbolButton(symbolName)
                }
            }
        }
    }

    private func symbolButton(_ symbolName: String) -> some View {
        let isSelected = selectedSymbolName == symbolName

        return DButton(
            style: .plain,
            action: {
                selectedSymbolName = symbolName
            },
            content: {
                Image(systemName: symbolName)
                    .font(DawnTextStyle.symbolPickerIcon)
                    .foregroundStyle(
                        isSelected
                            ? DawnColors.selectionForeground
                            : DawnColors.primaryForeground
                    )
                    .frame(maxWidth: .infinity, minHeight: 53)
                    .background(
                        isSelected
                            ? DawnColors.selectionBackground
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
        )
        .accessibilityLabel(symbolName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
