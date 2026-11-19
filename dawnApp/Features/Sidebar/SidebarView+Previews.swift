#if DEBUG

    import libdawn
    import libdawnUI
    import SwiftUI

    #Preview("Sidebar / Populated") {
        SidebarPreview(
            content: SidebarPreviewData.populated,
            selection: .context(SidebarPreviewData.academy.id)
        )
    }

    #Preview("Sidebar / Full") {
        SidebarPreview(
            content: SidebarPreviewData.full,
            selection: .context(SidebarPreviewData.academy.id),
            search: SidebarSearchState(isArchivedSectionExpanded: true)
        )
    }

    #Preview("Sidebar / Search") {
        SidebarPreview(
            content: SidebarPreviewData.populated,
            selection: .context(SidebarPreviewData.academy.id),
            search: SidebarSearchState(text: "App", isPresented: true)
        )
    }

    #Preview("Sidebar / Empty") {
        SidebarPreview(content: SidebarPreviewData.empty)
    }

    #Preview("Sidebar / Loading") {
        SidebarPreview(content: SidebarPreviewData.loading)
    }

    #Preview("Sidebar / Busy context") {
        SidebarPreview(
            content: SidebarPreviewData.busy,
            selection: .context(SidebarPreviewData.gaming.id)
        )
    }

    #Preview("Sidebar / Agent stopped") {
        SidebarPreview(
            content: SidebarPreviewData.disconnected,
            selection: .context(SidebarPreviewData.academy.id)
        )
    }

    #Preview("Sidebar / Accessibility required") {
        SidebarPreview(
            content: SidebarPreviewData.accessibilityRequired,
            selection: .context(SidebarPreviewData.academy.id)
        )
    }

    #Preview("Sidebar / Long names") {
        SidebarPreview(
            content: SidebarPreviewData.longNames,
            selection: .context(SidebarPreviewData.longName.id)
        )
    }

    #Preview("Sidebar / Archived") {
        SidebarPreview(
            content: SidebarPreviewData.populated,
            selection: .context(SidebarPreviewData.archived.id),
            search: SidebarSearchState(isArchivedSectionExpanded: true)
        )
    }

    #Preview("Sidebar / No update") {
        SidebarPreview(
            content: SidebarPreviewData.populated,
            selection: .context(SidebarPreviewData.study.id)
        )
    }

    #Preview("Sidebar / Settings") {
        SidebarPreview(
            content: SidebarPreviewData.populated,
            selection: .settings
        )
    }

    #Preview("Sidebar / About") {
        SidebarPreview(
            content: SidebarPreviewData.populated,
            selection: .about
        )
    }

    #Preview("Sidebar / Error") {
        SidebarPreview(content: SidebarPreviewData.failed)
    }

    #Preview("Sidebar / Row states") {
        sidebarRowStateGallery
            .frame(width: 300)
    }

    #Preview("Sidebar / Update available") {
        SidebarPreview(
            content: SidebarPreviewData.populated,
            availableUpdate: SidebarPreviewData.availableUpdate,
            selection: .context(SidebarPreviewData.academy.id),
        )
    }

    private struct SidebarPreview: View {
        private let content: SidebarContent
        private let availableUpdate: AvailableAppUpdate?
        private let search: SidebarSearchState

        @State private var selectedDestination: SidebarDestination?

        init(
            content: SidebarContent,
            availableUpdate: AvailableAppUpdate? = nil,
            selection: SidebarDestination? = nil,
            search: SidebarSearchState = SidebarSearchState()
        ) {
            self.content = content
            self.availableUpdate = availableUpdate
            self.search = search
            _selectedDestination = State(initialValue: selection)
        }

        var body: some View {
            HStack(spacing: 0) {
                SidebarView(
                    content: content,
                    availableUpdate: availableUpdate,
                    selectedDestination: $selectedDestination,
                    initialSearch: search,
                    onCreateContext: {},
                    onDismissError: {}
                )

                previewDetail
            }
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
            .frame(width: SidebarMetrics.windowWidth, height: SidebarMetrics.windowHeight)
        }

        private var previewDetail: some View {
            ZStack {
                DawnColors.primaryBackground
                    .ignoresSafeArea()

                Text(detailTitle)
                    .font(DawnTextStyle.sidebarFooter)
                    .foregroundStyle(DawnColors.sidebarSecondaryForeground)
            }
            .frame(width: SidebarMetrics.detailWidth)
            .frame(maxHeight: .infinity)
        }

        private var detailTitle: String {
            switch selectedDestination {
            case .settings:
                "Settings"
            case .about:
                "About"
            case .context(let identifier):
                contextName(identifier) ?? "Workspace"
            case .debug:
                "Debug"
            case nil:
                "No workspace selected"
            }
        }

        private func contextName(_ identifier: UUID) -> String? {
            let contexts = content.contexts + content.archivedContexts
            return contexts.first { $0.id == identifier }?.name
        }
    }

    @MainActor
    private var sidebarRowStateGallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            specimen("Default", name: "Study", state: SidebarRowState())
            specimen(
                "Selected",
                name: "Study",
                state: SidebarRowState(isSelected: true, activityText: "Last use Yesterday")
            )
            specimen(
                "Active",
                name: "Apple Developer Academy",
                state: SidebarRowState(isActive: true, activityText: "5h 12min in use")
            )
            specimen(
                "Selected and active",
                name: "Apple Developer Academy",
                state: SidebarRowState(
                    isSelected: true,
                    isActive: true,
                    activityText: "5h 12min in use"
                )
            )
            specimen(
                "Disabled",
                name: "Gaming",
                state: SidebarRowState(isEnabled: false)
            )
            specimen(
                "Loading",
                name: "Study",
                state: SidebarRowState(isLoading: true)
            )
            specimen(
                "Long name",
                name: SidebarPreviewData.longName.name,
                state: SidebarRowState(isSelected: true, isActive: true)
            )
        }
        .padding(16)
        .background {
            SidebarBackground()
        }
        .preferredColorScheme(.dark)
    }

    @MainActor
    private func specimen(
        _ title: String,
        name: String,
        state: SidebarRowState
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DawnTextStyle.sidebarSectionHeader)
                .foregroundStyle(DawnColors.sidebarSecondaryForeground)

            SidebarContextRow(name: name, symbol: "book.fill", state: state)
        }
    }

    private enum SidebarPreviewData {
        static let academy = makeContext(
            "10000000-0000-0000-0000-000000000001",
            name: "Apple Developer Academy",
            symbol: "apple.terminal.on.rectangle.fill"
        )

        static let gaming = makeContext(
            "10000000-0000-0000-0000-000000000002",
            name: "Gaming",
            symbol: "logo.playstation"
        )

        static let study = makeContext(
            "10000000-0000-0000-0000-000000000003",
            name: "Study",
            symbol: "book.fill"
        )

        static let archived = makeContext(
            "10000000-0000-0000-0000-000000000004",
            name: "Appppppple IPHONE 2 DUO!!!",
            symbol: "book.fill",
            isArchived: true
        )

        static let longName = makeContext(
            "10000000-0000-0000-0000-000000000005",
            name: "Apple Developer Academy International Design and Technology Studio",
            symbol: "apple.logo"
        )

        static let availableUpdate = AvailableAppUpdate(
            displayVersion: "1.2.0",
            buildVersion: "120",
            releaseNotesURL: URL(string: "https://update.opendawn.app"),
            informationURL: nil
        )

        static var populated: SidebarContent {
            SidebarContent(
                contexts: [academy, gaming, study],
                archivedContexts: [archived],
                activity: WorkspaceActivityState(
                    activeSession: .init(
                        contextID: academy.id,
                        startedAt: Date().addingTimeInterval(-5 * 3600 - 12 * 60)
                    ),
                    lastActiveAtByContextID: [
                        gaming.id: Date().addingTimeInterval(-86_400),
                        study.id: Date().addingTimeInterval(-86_400),
                    ]
                )
            )
        }

        static var empty: SidebarContent {
            SidebarContent()
        }

        static var full: SidebarContent {
            SidebarContent(
                contexts: [academy, gaming, study],
                archivedContexts: [oldContext],
                activity: WorkspaceActivityState(
                    activeSession: .init(contextID: academy.id, startedAt: Date().addingTimeInterval(-3600))
                ),
                isAgentRunning: false,
                interactionsDisabled: true,
            )
        }

        static let oldContext = makeContext(
            "10000000-0000-0000-0000-000000000006",
            name: "Personal (2024)",
            symbol: "archivebox",
            isArchived: true
        )

        static var loading: SidebarContent {
            SidebarContent(isLoading: true, interactionsDisabled: true)
        }

        static var busy: SidebarContent {
            var content = populated
            content.busyContextID = gaming.id
            content.interactionsDisabled = true
            return content
        }

        static var disconnected: SidebarContent {
            var content = populated
            content.isAgentRunning = false
            content.interactionsDisabled = true
            return content
        }

        static var accessibilityRequired: SidebarContent {
            var content = populated
            content.needsAccessibilityPermission = true
            return content
        }

        static var longNames: SidebarContent {
            SidebarContent(
                contexts: [longName, gaming, study],
                archivedContexts: [archived],
                activity: WorkspaceActivityState(
                    activeSession: .init(contextID: longName.id, startedAt: Date().addingTimeInterval(-600))
                )
            )
        }

        static var failed: SidebarContent {
            var content = populated
            content.errorMessages = [
                SidebarErrorMessage(text: "The workspace manager could not switch contexts.")
            ]
            content.isAgentRunning = false
            return content
        }

        private static func makeContext(
            _ identifier: String,
            name: String,
            symbol: String,
            isArchived: Bool = false
        ) -> WorkspaceContext {
            WorkspaceContext(
                id: UUID(uuidString: identifier) ?? UUID(),
                name: name,
                symbol: symbol,
                isArchived: isArchived
            )
        }
    }

#endif
