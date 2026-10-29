import libdawnUI
import SwiftUI

// swiftlint:disable:next todo
// FIXME: Placeholder while the activation-policy model is built on another branch.
// DeprActivationPolicy lets this screen compile in parallel. The choice is not saved,
// and Activate does not use it.
struct ContextDetailActivationPolicyPicker: View {
    @State private var selectedActivationPolicy: DeprActivationPolicy = .merge

    var body: some View {
        VStack(alignment: .leading) {
            Text("When switching to this context")
                .font(DawnTextStyle.sectionLabel)

            HStack(alignment: .top) {
                ForEach(DeprActivationPolicy.allCases, id: \.self) { policy in
                    DButton(style: .plain) {
                        selectedActivationPolicy = policy
                    } content: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 2) {
                                Image(systemName: policy.displaySymbol)
                                    .font(DawnTextStyle.primary)
                                    .foregroundStyle(
                                        selectedActivationPolicy == policy ?
                                        DawnColors.primaryForeground :
                                            DawnColors.secondaryForeground
                                    )
                                Text(policy.displayName)
                                    .font(DawnTextStyle.primary)
                                    .foregroundStyle(
                                        selectedActivationPolicy == policy ?
                                        DawnColors.primaryForeground :
                                            DawnColors.secondaryForeground
                                    )
                            }
                            Text(policy.displayDescription)
                                .font(DawnTextStyle.secondaryCaption)
                                .foregroundStyle(DawnColors.secondaryForeground)
                        }
                        .padding(24)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                        .background {
                            DawnColors.secondaryBackground
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DawnColors.primaryForeground,
                                        lineWidth: selectedActivationPolicy == policy ? 3 : 0)
                                .opacity(selectedActivationPolicy == policy ? 1 : 0)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .animation(.spring, value: selectedActivationPolicy)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
    }
}

@available(*, deprecated)
enum DeprActivationPolicy: String, Codable, Sendable, Equatable, CaseIterable {
    case hide
    case merge
    case close

    public var displaySymbol: String {
        switch self {
        case .hide: return "eye.slash"
        case .merge: return "interface.window.on.rectangle"
        case .close: return "xmark.seal"
        }
    }

    public var displayName: String {
        switch self {
        case .hide: return "Hide others"
        case .merge: return "Merge with others"
        case .close: return "Close others"
        }
    }

    public var displayDescription: String {
        switch self {
        case .hide: return "hide other apps windows and remove them from the dock"
        case .merge: return "open this workspaces apps while keeping the others open"
        case .close: return "close all other apps open on your mac"
        }
    }
}
