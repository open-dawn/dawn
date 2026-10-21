import libdawnUI
import SwiftUI

struct SidebarView: View {
    private let content: SidebarContent
    @Binding private var selectedDestination: SidebarDestination?
    private let onCreateContext: () -> Void
    private let onDismissError: () -> Void

    @State private var searchText: String
    @State private var isSearchPresented: Bool
    @State private var isArchivedSectionExpanded: Bool

    init(
        content: SidebarContent,
        selectedDestination: Binding<SidebarDestination?>,
        initialSearch: SidebarSearchState = SidebarSearchState(),
        onCreateContext: @escaping () -> Void,
        onDismissError: @escaping () -> Void = {}
    ) {
        self.content = content
        _selectedDestination = selectedDestination
        self.onCreateContext = onCreateContext
        self.onDismissError = onDismissError
        _searchText = State(initialValue: initialSearch.text)
        _isSearchPresented = State(initialValue: initialSearch.isPresented)
        _isArchivedSectionExpanded = State(
            initialValue: initialSearch.isArchivedSectionExpanded
        )
    }

    var body: some View {
        SidebarContextList(
            content: content,
            selectedDestination: $selectedDestination,
            isArchivedSectionExpanded: $isArchivedSectionExpanded,
            searchText: searchText,
            onCreateContext: onCreateContext
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            topSection
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomSection
        }
        .background {
            SidebarBackground()
                .ignoresSafeArea()
        }
        .frame(width: SidebarMetrics.width)
        .frame(maxHeight: .infinity)
    }

    private var topSection: some View {
        VStack(spacing: SidebarMetrics.sectionSpacing) {
            SidebarQuickActions(
                searchText: $searchText,
                isSearchPresented: $isSearchPresented,
                interactionsDisabled: content.interactionsDisabled,
                onCreateContext: onCreateContext
            )
        }
        .padding(.horizontal, SidebarMetrics.horizontalPadding)
        .padding(.top, SidebarMetrics.footerSpacing)
        .padding(.bottom, SidebarMetrics.footerSpacing)
        .frame(maxWidth: .infinity)
        .background {
            SidebarBackground()
        }
    }

    private var bottomSection: some View {
        SidebarFooter(
            content: content,
            selectedDestination: $selectedDestination,
            onDismissError: onDismissError
        )
        .padding(.horizontal, SidebarMetrics.horizontalPadding)
        .padding(.top, SidebarMetrics.footerSpacing)
        .padding(.bottom, SidebarMetrics.horizontalPadding)
        .frame(maxWidth: .infinity)
        .background {
            SidebarBackground()
        }
    }
}
