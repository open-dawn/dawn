import libdawnUI
import SwiftUI

struct SidebarQuickActions: View {
    @Binding var searchText: String
    @Binding var isSearchPresented: Bool
    let interactionsDisabled: Bool
    let onCreateContext: () -> Void

    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SidebarButton(
                title: "New Workspace",
                systemImage: "plus",
                expands: true,
                action: onCreateContext
            )
            .disabled(interactionsDisabled)

            if isSearchPresented {
                searchField
            } else {
                SidebarButton(
                    title: "Search",
                    systemImage: "magnifyingglass",
                    expands: true,
                    action: presentSearch
                )
                .keyboardShortcut("f", modifiers: .command)
            }
        }
        .onChange(of: isSearchPresented) { _, isPresented in
            isSearchFieldFocused = isPresented
            if !isPresented {
                searchText = ""
            }
        }
        .onAppear {
            if isSearchPresented {
                isSearchFieldFocused = true
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: SidebarMetrics.iconTextSpacing) {
            Image(systemName: "magnifyingglass")
                .font(DawnTextStyle.sidebarIcon)
                .foregroundStyle(DawnColors.sidebarIcon)
                .frame(width: SidebarMetrics.iconSize, height: SidebarMetrics.iconSize)
                .accessibilityHidden(true)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(DawnTextStyle.sidebarRow)
                .foregroundStyle(DawnColors.sidebarForeground)
                .tint(DawnColors.sidebarActive)
                .focused($isSearchFieldFocused)
                .accessibilityLabel("Search workspaces")
                .onKeyPress(.escape) {
                    isSearchPresented = false
                    return .handled
                }

            Button(action: dismissSearch) {
                Image(systemName: "xmark")
                    .font(DawnTextStyle.sidebarChevron)
                    .foregroundStyle(DawnColors.sidebarIcon)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help("Clear search")
            .accessibilityLabel("Clear search")
        }
        .padding(.horizontal, 8)
        .frame(minHeight: SidebarMetrics.controlHeight)
        .background {
            RoundedRectangle(cornerRadius: SidebarMetrics.cornerRadius, style: .continuous)
                .fill(DawnColors.textFieldInset)
        }
    }

    private func presentSearch() {
        isSearchPresented = true
    }

    private func dismissSearch() {
        isSearchPresented = false
    }
}
