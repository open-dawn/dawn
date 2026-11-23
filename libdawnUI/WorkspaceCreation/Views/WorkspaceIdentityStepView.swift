//
//  WorkspaceIdentityStepView.swift
//  dawn
//
//  Created by Rafael Venetikides on 20/10/26.
//

import Foundation
import SwiftUI
import libdawn

struct WorkspaceIdentityStepView: View {
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
                    .font(DawnTextStyle.screenTitle)
                    .dawnZainOpticalAlignment()

                (Text("Choose a ")

                    + Text("name")
                    .font(DawnTextStyle.emphasizedBody)
                    .foregroundColor(DawnColors.emphasizedBody)

                    + Text(" and ")

                    + Text("symbol")
                    .font(DawnTextStyle.emphasizedBody)
                    .foregroundColor(DawnColors.emphasizedBody)

                    + Text(" for your workspace"))
                    .font(DawnTextStyle.body)
                    .foregroundColor(DawnColors.menuItemSecondaryForeground)
            }
            .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 20) {
                nameField
                symbolPicker
            }

            Spacer()

            DButton(action: onNext) {
                Text("Next")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!canContinue)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Name")
                .font(DawnTextStyle.fieldLabel)

            TextField("Workspace name", text: $name)
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
                ForEach(WorkspaceSymbols.allCases, id: \.self) { symbolName in
                    symbolButton(symbolName.rawValue)
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
