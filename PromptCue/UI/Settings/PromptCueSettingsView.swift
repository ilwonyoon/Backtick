import SwiftUI

@MainActor
struct PromptCueSettingsView: View {
    let selectedTab: SettingsTab
    let onSelectTab: ((SettingsTab) -> Void)?
    @ObservedObject var screenshotSettingsModel: ScreenshotSettingsModel
    @ObservedObject var exportTailSettingsModel: PromptExportTailSettingsModel
    @ObservedObject var retentionSettingsModel: CardRetentionSettingsModel
    @ObservedObject var cloudSyncSettingsModel: CloudSyncSettingsModel
    @ObservedObject var appearanceSettingsModel: AppearanceSettingsModel
    @ObservedObject var mcpConnectorSettingsModel: MCPConnectorSettingsModel
    @State var expandedSetupClient: MCPConnectorClient?
    @State var expandedManualSetupClient: MCPConnectorClient?
    @State var expandedToolsClient: MCPConnectorClient?
    @State var didCopySetupCommand = false
    @State var didCopyConfigSnippet = false

    init(
        selectedTab: SettingsTab,
        onSelectTab: ((SettingsTab) -> Void)? = nil,
        screenshotSettingsModel: ScreenshotSettingsModel,
        exportTailSettingsModel: PromptExportTailSettingsModel,
        retentionSettingsModel: CardRetentionSettingsModel,
        cloudSyncSettingsModel: CloudSyncSettingsModel,
        appearanceSettingsModel: AppearanceSettingsModel,
        mcpConnectorSettingsModel: MCPConnectorSettingsModel
    ) {
        self.selectedTab = selectedTab
        self.onSelectTab = onSelectTab
        self.screenshotSettingsModel = screenshotSettingsModel
        self.exportTailSettingsModel = exportTailSettingsModel
        self.retentionSettingsModel = retentionSettingsModel
        self.cloudSyncSettingsModel = cloudSyncSettingsModel
        self.appearanceSettingsModel = appearanceSettingsModel
        self.mcpConnectorSettingsModel = mcpConnectorSettingsModel
    }

    init() {
        self.selectedTab = .general
        self.onSelectTab = nil
        self.screenshotSettingsModel = ScreenshotSettingsModel()
        self.exportTailSettingsModel = PromptExportTailSettingsModel()
        self.retentionSettingsModel = CardRetentionSettingsModel()
        self.cloudSyncSettingsModel = CloudSyncSettingsModel()
        self.appearanceSettingsModel = AppearanceSettingsModel()
        self.mcpConnectorSettingsModel = MCPConnectorSettingsModel()
    }

    var body: some View {
        NavigationSplitView {
            settingsSidebar
                .navigationSplitViewColumnWidth(
                    min: SettingsTokens.Layout.sidebarWidth,
                    ideal: SettingsTokens.Layout.sidebarWidth,
                    max: SettingsTokens.Layout.sidebarWidth
                )
        } detail: {
            settingsContentPane
        }
        .navigationSplitViewStyle(.balanced)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(
            width: PanelMetrics.settingsPanelWidth,
            height: PanelMetrics.settingsPanelHeight
        )
        .onAppear {
            screenshotSettingsModel.refresh()
            exportTailSettingsModel.refresh()
            retentionSettingsModel.refresh()
            cloudSyncSettingsModel.refresh()
            appearanceSettingsModel.refresh()
            mcpConnectorSettingsModel.refresh()
        }
        .onChange(of: mcpConnectorSettingsModel.connectionState) { _, newValue in
            if case .passed = newValue {
                expandedSetupClient = nil
                expandedManualSetupClient = nil
                return
            }

            expandedToolsClient = nil
        }
    }

    private var settingsContentPane: some View {
        selectedTabContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .toolbar(removing: .sidebarToggle)
            .background {
                SettingsSemanticTokens.Surface.contentBackground
                    .ignoresSafeArea()
            }
    }

    private var settingsPageHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(selectedTab.title)
                .font(SettingsTokens.Typography.pageTitle)
                .foregroundStyle(SettingsSemanticTokens.Text.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .general:
            generalPage
        case .capture:
            capturePage
        case .stack:
            stackPage
        case .connectors:
            connectorsPage
        }
    }

    private var settingsSidebar: some View {
        ZStack {
            settingsSidebarBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SettingsTokens.Layout.sidebarItemSpacing) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        SettingsSidebarItem(
                            title: tab.title,
                            systemImage: tab.sidebarIconName,
                            iconFill: tab.sidebarIconColor,
                            isSelected: tab == selectedTab,
                            usesManualSelection: true
                        ) {
                            onSelectTab?(tab)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, SettingsTokens.Layout.sidebarHorizontalPadding)
                .padding(.vertical, SettingsTokens.Layout.sidebarVerticalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var settingsSidebarBackground: some View {
        ZStack {
            SettingsSemanticTokens.Surface.sidebarBackground

            LinearGradient(
                colors: [
                    SettingsSemanticTokens.Surface.sidebarBackgroundTopTint,
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    SettingsSemanticTokens.Surface.sidebarBackgroundBottomShade
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    func settingsScrollPage<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        let pageContent = content()

        return GeometryReader { proxy in
            let contentWidth = max(
                0,
                min(
                    SettingsTokens.Layout.contentMaxWidth,
                    proxy.size.width
                        - SettingsTokens.Layout.pageLeadingPadding
                        - SettingsTokens.Layout.pageTrailingPadding
                )
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    settingsPageHeader

                    VStack(alignment: .leading, spacing: SettingsTokens.Layout.sectionSpacing) {
                        pageContent
                    }
                    .padding(.top, SettingsTokens.Layout.titleToFirstSectionSpacing)
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.leading, SettingsTokens.Layout.pageLeadingPadding)
                .padding(.trailing, SettingsTokens.Layout.pageTrailingPadding)
                .padding(.top, SettingsTokens.Layout.pageTopPadding)
                .padding(.bottom, SettingsTokens.Layout.pageBottomPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
