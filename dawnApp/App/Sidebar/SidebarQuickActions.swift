import libdawnUI
import SwiftUI

struct SidebarQuickActions: View {
    @Binding var searchText: String
    @Binding var isSearchPresented: Bool
    let interactionsDisabled: Bool
    let onCreateContext: () -> Void

    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SidebarInlineButton(
                title: "New context",
                systemImage: "plus",
                action: onCreateContext
            )
            .disabled(interactionsDisabled)

            if isSearchPresented {
                searchField
            } else {
                SidebarInlineButton(
                    title: "Search",
                    systemImage: "magnifyingglass",
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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(DawnTextStyle.sidebarIcon)
                .foregroundStyle(DawnColors.sidebarIcon)
                .accessibilityHidden(true)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(DawnTextStyle.sidebarRow)
                .foregroundStyle(DawnColors.sidebarForeground)
                .tint(DawnColors.sidebarActive)
                .focused($isSearchFieldFocused)
                .accessibilityLabel("Search contexts")
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
                .fill(DawnColors.sidebarSearchField)
        }
    }

    private func presentSearch() {
        isSearchPresented = true
    }

    private func dismissSearch() {
        isSearchPresented = false
    }
}

private struct SidebarInlineButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(DawnTextStyle.sidebarIcon)
                    .foregroundStyle(DawnColors.sidebarIcon)
                    .frame(width: SidebarMetrics.iconSize, height: SidebarMetrics.iconSize)

                Text(title)
                    .font(DawnTextStyle.sidebarAction)
                    .foregroundStyle(DawnColors.sidebarForeground)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: SidebarMetrics.controlHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}
