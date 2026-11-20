import libdawn
import libdawnUI
import SwiftUI

struct ContextDetailSymbolPicker: View {
    let symbol: String
    let onSymbolChange: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Symbol")
                .font(DawnTextStyle.detailSectionLabel)
                .foregroundStyle(DawnColors.primaryForeground)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ContextSymbols.allCases, id: \.self) { candidate in
                        DButton(
                            style: .plain,
                            action: {
                                onSymbolChange(candidate.rawValue)
                            },
                            content: {
                                Image(systemName: candidate.rawValue)
                                    .font(.system(size: 24))
                                    .foregroundStyle(
                                        candidate.rawValue == symbol
                                        ? DawnColors.activationPolicySelectedTitle
                                        : DawnColors.activationPolicyDescription
                                    )
                                    .frame(width: 48, height: 47)
                                    .background(
                                        candidate.rawValue == symbol
                                        ? DawnColors.activationPolicySelectedBackground
                                        : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        )
                        .accessibilityAddTraits(candidate.rawValue == symbol ? .isSelected : [])
                    }
                }
            }
        }
    }
}
