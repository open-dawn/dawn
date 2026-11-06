import libdawn
import libdawnUI
import SwiftUI

struct ContextDetailSymbolPicker: View {
    let symbol: String
    let onSymbolChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text("Symbol")
                .font(DawnTextStyle.sectionLabel)

            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(ContextSymbols.allCases, id: \.self) { candidate in
                        DButton(
                            style: .plain,
                            action: {
                                onSymbolChange(candidate.rawValue)
                            },
                            content: {
                                Image(systemName: candidate.rawValue)
                                    .font(DawnTextStyle.symbolPickerIcon)
                                    .foregroundStyle(
                                        candidate.rawValue == symbol
                                        ? DawnColors.selectionForeground
                                        : DawnColors.primaryForeground
                                    )
                                    .frame(maxWidth: .infinity, minHeight: 53)
                                    .background(
                                        candidate.rawValue == symbol
                                        ? DawnColors.selectionBackground
                                        : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                        )
                        .accessibilityAddTraits(candidate.rawValue == symbol ? .isSelected : [])
                        .frame(width: 56, height: 56)
                    }
                }
            }
        }
    }
}
