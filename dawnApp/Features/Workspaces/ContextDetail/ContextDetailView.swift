import libdawn
import libdawnUI
import SwiftUI

struct ContextDetailView: View {
    @State var context: WorkspaceContext
    let viewModel: ContextDetailViewModel
    let interactionsDisabled: Bool
    let onDelete: (WorkspaceContext) -> Void

    @State var selectedActivationPolicy: DeprActivationPolicy = .merge

    var isActive: Bool {
        context.id == viewModel.activeContextID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack(spacing: 24) {
                Label(context.name, systemImage: context.symbol)
                    .contentTransition(.symbolEffect)
                    .font(DawnTextStyle.screenTitle)

                Spacer()

                if isActive {
                    DButton(style: .danger) {
                        print("stop")
                    } content: {
                        Text("Stop")
                    } leading: {
                        Image(systemName: "stop.fill")
                    }
                } else {
                    DButton(style: .success) {
                        print("stop")
                    } content: {
                        Text("Activate")
                    } leading: {
                        Image(systemName: "play.fill")
                    }
                }

                DButton(style: .icon) {

                } content: {
                    Image(systemName: "ellipsis.circle")
                }

            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)

            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading) {
                    Text("Name")
                        .font(DawnTextStyle.sectionLabel)

                    HStack {
                        Image(systemName: "textformat")
                            .font(DawnTextStyle.textFieldSecondaryIcon)
                            .foregroundStyle(DawnColors.secondaryForeground)

                        TextField("Name", text: Binding(get: {
                            context.name
                        }, set: { newName in
                            context.name = newName
                        }))
                        .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background {
                        DawnColors.textFieldInset
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading) {
                    Text("Symbol")
                        .font(DawnTextStyle.sectionLabel)

                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(ContextSymbols.allCases, id: \.self) { symbol in
                                DButton(
                                    style: .plain,
                                    action: {
                                        withAnimation {
                                            context.symbol = symbol.rawValue
                                        }
                                    },
                                    content: {
                                        Image(systemName: symbol.rawValue)
                                            .font(DawnTextStyle.symbolPickerIcon)
                                            .foregroundStyle(
                                                symbol.rawValue == context.symbol
                                                ? DawnColors.selectionForeground
                                                : DawnColors.primaryForeground
                                            )
                                            .frame(maxWidth: .infinity, minHeight: 53)
                                            .background(
                                                symbol.rawValue == context.symbol
                                                ? DawnColors.selectionBackground
                                                : Color.clear
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 7))
                                    }
                                )
                                .accessibilityAddTraits(symbol.rawValue == context.symbol ? .isSelected : [])
                                .frame(width: 56, height: 56)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)

            VStack(alignment: .leading) {
                Text("Applications")
                    .font(DawnTextStyle.sectionLabel)

                FlowLayout(spacing: 8) {
                    if context.applications.isEmpty {
                        Text("No applications added to this context.")
                            .font(DawnTextStyle.primary)
                            .foregroundStyle(DawnColors.secondaryForeground)
                            .padding()
                    }

                    ForEach(context.applications) { app in
                        DButton(style: .plain) {

                        } content: {
                            HStack {
                                if let appPath = app.applicationURL?.path(percentEncoded: false) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: appPath))
                                } else {
                                    Image(systemName: "questionmark.square")
                                }
                                Text(app.displayName)
                                    .font(DawnTextStyle.secondary)

                                Image(systemName: "chevron.down")
                                    .padding(.leading, 16)
                            }
                            .padding(8)
                            .background {
                                DawnColors.secondaryBackground
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .padding(.horizontal, 32)

            VStack(alignment: .leading) {
                Text("When switching to this context")
                    .font(DawnTextStyle.sectionLabel)

                HStack {
                    ForEach(DeprActivationPolicy.allCases, id: \.self) { policy in
                        DButton(style: .plain) {
                            withAnimation {
                                selectedActivationPolicy = policy
                            }
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
                        }
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
