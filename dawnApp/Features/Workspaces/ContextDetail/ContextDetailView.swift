import libdawn
import libdawnUI
import SwiftUI

struct ContextDetailView: View {
    let context: WorkspaceContext
    let viewModel: ContextDetailViewModel
    let interactionsDisabled: Bool
    let onDelete: (WorkspaceContext) -> Void

    @State var selectedActivationPolicy: DeprActivationPolicy = .merge

    var isActive: Bool {
        context.id == viewModel.activeContextID
    }

    private var editedContext: WorkspaceContext {
        if let draft = viewModel.draft, draft.id == context.id {
            return draft
        }
        return context
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                HStack(spacing: 24) {
                    Label(editedContext.name, systemImage: editedContext.symbol)
                        .contentTransition(.symbolEffect)
                        .font(DawnTextStyle.screenTitle)
                        .animation(.spring, value: editedContext.symbol)

                    Spacer()

                    if isActive {
                        // FIXME: Stop has no action yet. There is no stop event on the agent.
                        DButton(style: .danger) {
                        } content: {
                            Text("Stop")
                        } leading: {
                            Image(systemName: "stop.fill")
                        }
                        .disabled(interactionsDisabled)
                    } else {
                        DButton(style: .success) {
                            Task {
                                await viewModel.runContext(context)
                            }
                        } content: {
                            Text("Activate")
                        } leading: {
                            Image(systemName: "play.fill")
                        }
                        .disabled(interactionsDisabled)
                    }

                    // FIXME: This should be a menu with Delete (trash) and Archive (shippingbox).
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
                                editedContext.name
                            }, set: { newName in
                                viewModel.setName(newName)
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
                                            viewModel.setSymbol(symbol.rawValue)
                                        },
                                        content: {
                                            Image(systemName: symbol.rawValue)
                                                .font(DawnTextStyle.symbolPickerIcon)
                                                .foregroundStyle(
                                                    symbol.rawValue == editedContext.symbol
                                                    ? DawnColors.selectionForeground
                                                    : DawnColors.primaryForeground
                                                )
                                                .frame(maxWidth: .infinity, minHeight: 53)
                                                .background(
                                                    symbol.rawValue == editedContext.symbol
                                                    ? DawnColors.selectionBackground
                                                    : Color.clear
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 7))
                                        }
                                    )
                                    .accessibilityAddTraits(symbol.rawValue == editedContext.symbol ? .isSelected : [])
                                    .frame(width: 56, height: 56)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)

                // FIXME: Application rows and the add button are not implemented yet.
                VStack(alignment: .leading) {
                    Text("Applications")
                        .font(DawnTextStyle.sectionLabel)

                    FlowLayout(spacing: 8) {
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

                        DButton(style: .plain) {

                        } content: {
                            Image(systemName: "plus")
                                .padding(8)
                                .background {
                                    DawnColors.secondaryBackground
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(9.5)
                        }

                        if context.applications.isEmpty {
                            Text("No applications added to this context.")
                                .font(DawnTextStyle.primary)
                                .foregroundStyle(DawnColors.secondaryForeground)
                                .padding()
                        }
                    }
                }
                .padding(.horizontal, 32)

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

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onChange(of: context, initial: true) { _, snapshot in
                viewModel.adopt(snapshot)
            }
        }
    }
}

// FIXME: Placeholder while the activation-policy model is built on another branch.
// DeprActivationPolicy lets this screen compile in parallel. The choice is not saved,
// and Activate does not use it.
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
