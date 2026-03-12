import SwiftUI

extension PromptCueSettingsView {
    var connectorsPage: some View {
        settingsScrollPage {
            connectorsContent
        }
    }

    @ViewBuilder
    private var connectorsContent: some View {
        if focusedConnectorClients.isEmpty {
            SettingsGroupSurface {
                Text("Connector status is unavailable right now.")
                    .font(SettingsTokens.Typography.rowLabel)
                    .foregroundStyle(SettingsSemanticTokens.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SettingsTokens.Layout.groupInset)
                    .padding(.vertical, PrimitiveTokens.Space.sm)
            }
        } else {
            SettingsGroupSurface {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(focusedConnectorClients.enumerated()), id: \.element.client) { index, client in
                        focusedConnectorRow(client, showsDivider: index < focusedConnectorClients.count - 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func focusedConnectorRow(
        _ client: MCPConnectorClientStatus,
        showsDivider: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: PrimitiveTokens.Space.xs) {
            HStack(alignment: .center, spacing: PrimitiveTokens.Space.xs) {
                connectorClientBadge(
                    for: client.client,
                    tone: connectorStatusTone(for: client)
                )

                VStack(alignment: .leading, spacing: PrimitiveTokens.Space.xxxs) {
                    Text(client.client.title)
                        .font(PrimitiveTokens.Typography.bodyStrong)
                        .foregroundStyle(SemanticTokens.Text.primary)

                    Text(focusedConnectorDetail(for: client))
                        .font(PrimitiveTokens.Typography.meta)
                        .foregroundStyle(SemanticTokens.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: PrimitiveTokens.Space.xs)

                focusedConnectorAccessory(for: client)
            }

            if shouldShowInlineSetup(for: client) {
                connectorInlinePanel {
                    VStack(alignment: .leading, spacing: PrimitiveTokens.Space.xs) {
                        Text(configuredSetupPrompt(for: client))
                            .font(PrimitiveTokens.Typography.meta)
                            .foregroundStyle(SemanticTokens.Text.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let addCommand = client.addCommand {
                            advancedValueBlock(addCommand, emphasized: true)
                        }

                        HStack(spacing: PrimitiveTokens.Space.xs) {
                            Button(didCopySetupCommand ? "Copied" : "Copy Command") {
                                mcpConnectorSettingsModel.copyAddCommand(for: client.client)
                                showSetupCommandCopiedFeedback()
                            }
                            .controlSize(.small)
                            .buttonStyle(.borderedProminent)

                            Button(
                                isManualSetupExpanded(for: client)
                                    ? "Hide Manual Setup"
                                    : "Use Config File Instead"
                            ) {
                                toggleManualSetup(for: client)
                            }
                            .controlSize(.small)
                            .buttonStyle(.bordered)
                        }

                        if isManualSetupExpanded(for: client),
                           let configSnippet = client.configSnippet {
                            VStack(alignment: .leading, spacing: PrimitiveTokens.Space.xs) {
                                Text(manualSetupDestinationSummary(for: client))
                                    .font(PrimitiveTokens.Typography.meta)
                                    .foregroundStyle(SemanticTokens.Text.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                advancedValueBlock(configSnippet)

                                HStack(spacing: PrimitiveTokens.Space.xs) {
                                    Button(didCopyConfigSnippet ? "Copied" : "Copy Config") {
                                        mcpConnectorSettingsModel.copyConfigSnippet(for: client.client)
                                        showConfigSnippetCopiedFeedback()
                                    }
                                    .controlSize(.small)

                                    if client.projectConfig != nil {
                                        Button(projectConfigButtonTitle(for: client.client)) {
                                            mcpConnectorSettingsModel.openProjectConfig(for: client.client)
                                        }
                                        .controlSize(.small)
                                    }

                                    Button(homeConfigButtonTitle(for: client.client)) {
                                        mcpConnectorSettingsModel.openHomeConfig(for: client.client)
                                    }
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }
            }

            if shouldShowRepairBlock(for: client) {
                connectorInlinePanel {
                    VStack(alignment: .leading, spacing: PrimitiveTokens.Space.xs) {
                        Text("\(client.client.title) needs one repair before Backtick can respond again.")
                            .font(PrimitiveTokens.Typography.metaStrong)
                            .foregroundStyle(ConnectorChipTone.danger.foreground)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let failureDetail = mcpConnectorSettingsModel.clientFailureDetail(for: client) {
                            advancedMessageBlock(failureDetail)
                        }

                        HStack(spacing: PrimitiveTokens.Space.xs) {
                            Button("Verify Again") {
                                mcpConnectorSettingsModel.runServerTest()
                            }
                            .controlSize(.small)
                            .disabled(mcpConnectorSettingsModel.connectionState.isRunning)

                            Button("Open \(client.client.title) Config") {
                                mcpConnectorSettingsModel.openPreferredConfig(for: client.client)
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }

            if shouldShowConnectedTools(for: client) {
                connectorInlinePanel {
                    VStack(alignment: .leading, spacing: PrimitiveTokens.Space.xs) {
                        Text("\(mcpConnectorSettingsModel.connectedToolNames(for: client).count) tools are ready in \(client.client.title).")
                            .font(PrimitiveTokens.Typography.metaStrong)
                            .foregroundStyle(SemanticTokens.Text.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        connectorToolGrid(toolNames: mcpConnectorSettingsModel.connectedToolNames(for: client))
                    }
                }
            }

            if showsDivider {
                Rectangle()
                    .fill(SettingsSemanticTokens.Border.rowSeparator)
                    .frame(height: 1)
            }
        }
        .padding(.horizontal, SettingsTokens.Layout.groupInset)
        .padding(.vertical, PrimitiveTokens.Space.xs)
    }

    private func focusedConnectorDetail(for client: MCPConnectorClientStatus) -> String {
        if !mcpConnectorSettingsModel.isServerAvailable {
            return "Restart Backtick, then try again."
        }

        if !client.hasDetectedCLI {
            return "Install \(client.client.title) on this Mac."
        }

        if !client.hasConfiguredScope {
            return "Not connected yet."
        }

        switch mcpConnectorSettingsModel.connectionState {
        case .idle:
            return "Connected, but not verified yet."
        case .running:
            return "Checking the connection now."
        case .passed(let report):
            return "Connected. \(report.toolNames.count) tools available."
        case .failed:
            return "Connected, but verification failed."
        }
    }

    private func focusedPrimaryAction(for client: MCPConnectorClientStatus) -> MCPConnectorPrimaryAction? {
        guard mcpConnectorSettingsModel.isServerAvailable else {
            return nil
        }

        return mcpConnectorSettingsModel.primaryAction(for: client)
    }

    @ViewBuilder
    private func focusedConnectorAccessory(for client: MCPConnectorClientStatus) -> some View {
        if !mcpConnectorSettingsModel.isServerAvailable {
            EmptyView()
        } else {
            switch focusedPrimaryAction(for: client) {
            case .copyAddCommand:
                Button(isSetupExpanded(for: client) ? "Hide" : "Connect") {
                    let wasExpanded = isSetupExpanded(for: client)
                    expandedSetupClient = wasExpanded ? nil : client.client
                    expandedManualSetupClient = nil
                    expandedToolsClient = nil
                    if !wasExpanded {
                        didCopySetupCommand = false
                    }
                }
            case .openDocumentation:
                Button("Install") {
                    mcpConnectorSettingsModel.openDocumentation(for: client.client)
                }
            case .runServerTest:
                Button(repairActionTitle(for: client)) {
                    mcpConnectorSettingsModel.runServerTest()
                }
                .disabled(mcpConnectorSettingsModel.connectionState.isRunning)
            case nil:
                if case .passed = mcpConnectorSettingsModel.connectionState,
                   client.hasConfiguredScope {
                    HStack(spacing: PrimitiveTokens.Space.xs) {
                        SettingsStatusBadge(
                            title: "Connected",
                            tone: .success
                        )

                        Button(
                            isToolsExpanded(for: client)
                                ? "Hide Tools"
                                : "Show Tools"
                        ) {
                            expandedToolsClient = isToolsExpanded(for: client) ? nil : client.client
                        }
                        .controlSize(.small)
                    }
                } else {
                    EmptyView()
                }
            }
        }
    }

    private func repairActionTitle(for client: MCPConnectorClientStatus) -> String {
        if case .failed = mcpConnectorSettingsModel.connectionState {
            return "Fix"
        }

        return "Verify"
    }

    private func connectorStatusTone(for client: MCPConnectorClientStatus) -> ConnectorChipTone {
        guard client.hasConfiguredScope else {
            return .neutral
        }

        switch mcpConnectorSettingsModel.connectionState {
        case .passed:
            return .success
        case .failed:
            return .danger
        case .idle, .running:
            return .neutral
        }
    }

    private func connectorStatusDotColor(for tone: ConnectorChipTone) -> Color {
        switch tone {
        case .neutral:
            return SemanticTokens.Text.secondary
        case .accent, .success, .warning, .danger:
            return tone.foreground
        }
    }

    private func configuredSetupPrompt(for client: MCPConnectorClientStatus) -> String {
        if client.hasOtherConfigFiles {
            return "Run this in Terminal and \(client.client.title) will pick up Backtick from the existing config."
        }

        if client.client == .claudeCode {
            return "Copy this command for project setup. If you want Claude Code available everywhere, use Config File Instead and paste the snippet into ~/.claude.json."
        }

        return "Copy this command, paste it into Terminal, and press Return."
    }

    private func manualSetupDestinationSummary(for client: MCPConnectorClientStatus) -> String {
        switch client.client {
        case .claudeCode:
            if client.projectConfig != nil {
                return "Paste this into ~/.claude.json for global use, or .mcp.json in this project for project-only use."
            }

            return "Paste this into ~/.claude.json for global use."

        case .codex:
            if client.projectConfig != nil {
                return "Paste this into ~/.codex/config.toml for global use, or .codex/config.toml in this project for project-only use."
            }

            return "Paste this into ~/.codex/config.toml for global use."
        }
    }

    private func projectConfigButtonTitle(for client: MCPConnectorClient) -> String {
        switch client {
        case .claudeCode:
            return "Open .mcp.json"
        case .codex:
            return "Open Project Config"
        }
    }

    private func homeConfigButtonTitle(for client: MCPConnectorClient) -> String {
        switch client {
        case .claudeCode:
            return "Open ~/.claude.json"
        case .codex:
            return "Open ~/.codex/config.toml"
        }
    }

    private func shouldShowInlineSetup(for client: MCPConnectorClientStatus) -> Bool {
        guard client.hasDetectedCLI, !client.hasConfiguredScope else {
            return false
        }

        return expandedSetupClient == client.client
    }

    private func shouldShowRepairBlock(for client: MCPConnectorClientStatus) -> Bool {
        guard client.hasConfiguredScope else {
            return false
        }

        if case .failed = mcpConnectorSettingsModel.connectionState {
            return true
        }

        return false
    }

    private func shouldShowConnectedTools(for client: MCPConnectorClientStatus) -> Bool {
        guard client.hasConfiguredScope else {
            return false
        }

        guard case .passed = mcpConnectorSettingsModel.connectionState else {
            return false
        }

        return expandedToolsClient == client.client
    }

    private func isSetupExpanded(for client: MCPConnectorClientStatus) -> Bool {
        expandedSetupClient == client.client
    }

    private func isManualSetupExpanded(for client: MCPConnectorClientStatus) -> Bool {
        expandedManualSetupClient == client.client
    }

    private func isToolsExpanded(for client: MCPConnectorClientStatus) -> Bool {
        expandedToolsClient == client.client
    }

    private func toggleManualSetup(for client: MCPConnectorClientStatus) {
        let isExpanded = isManualSetupExpanded(for: client)
        expandedManualSetupClient = isExpanded ? nil : client.client
        if !isExpanded {
            didCopyConfigSnippet = false
        }
    }

    private func connectorInlinePanel<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        SettingsInlinePanel {
            VStack(alignment: .leading, spacing: PrimitiveTokens.Space.xs) {
                content()
            }
        }
    }

    private func connectorToolGrid(toolNames: [String]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 132), spacing: PrimitiveTokens.Space.xs)],
            alignment: .leading,
            spacing: PrimitiveTokens.Space.xs
        ) {
            ForEach(toolNames, id: \.self) { toolName in
                PromptCueChip(
                    fill: SemanticTokens.Surface.raisedFill,
                    border: SemanticTokens.Border.subtle
                ) {
                    Text(toolName)
                        .font(PrimitiveTokens.Typography.codeStrong)
                        .foregroundStyle(SemanticTokens.Text.primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var focusedConnectorClients: [MCPConnectorClientStatus] {
        let order = Dictionary(uniqueKeysWithValues: MCPConnectorClient.allCases.enumerated().map { ($1, $0) })
        return mcpConnectorSettingsModel.clients.sorted {
            (order[$0.client] ?? 0) < (order[$1.client] ?? 0)
        }
    }

    private func connectorClientBadge(
        for client: MCPConnectorClient,
        tone: ConnectorChipTone = .neutral
    ) -> some View {
        let badgeShape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        return ZStack {
            if let assetName = clientBadgeAssetName(for: client) {
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(badgeShape)
            } else {
                RoundedRectangle(cornerRadius: PrimitiveTokens.Radius.md, style: .continuous)
                    .fill(SemanticTokens.Text.primary.opacity(0.9))

                RoundedRectangle(cornerRadius: PrimitiveTokens.Radius.md, style: .continuous)
                    .stroke(SemanticTokens.Text.primary.opacity(0.08), lineWidth: PrimitiveTokens.Stroke.subtle)

                Image(systemName: clientBadgeSymbol(for: client))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SemanticTokens.Surface.previewBackdropBottom)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .fill(SemanticTokens.Surface.previewBackdropBottom)
                    .frame(width: 12, height: 12)

                Circle()
                    .fill(connectorStatusDotColor(for: tone))
                    .frame(width: 9, height: 9)
            }
            .offset(x: 1, y: 1)
        }
        .frame(width: 44, height: 44)
    }

    private func clientBadgeAssetName(for client: MCPConnectorClient) -> String? {
        switch client {
        case .claudeCode:
            return "ClaudeCodeIcon"
        case .codex:
            return "CodexIcon"
        }
    }

    private func clientBadgeSymbol(for client: MCPConnectorClient) -> String {
        switch client {
        case .claudeCode:
            return "chevron.left.forwardslash.chevron.right"
        case .codex:
            return "terminal"
        }
    }

    private func showSetupCommandCopiedFeedback() {
        didCopySetupCommand = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            didCopySetupCommand = false
        }
    }

    private func showConfigSnippetCopiedFeedback() {
        didCopyConfigSnippet = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            didCopyConfigSnippet = false
        }
    }

    private func advancedValueBlock(
        _ text: String,
        emphasized: Bool = false
    ) -> some View {
        Text(verbatim: displayConnectorText(text))
            .font(emphasized ? PrimitiveTokens.Typography.codeStrong : PrimitiveTokens.Typography.code)
            .foregroundStyle(emphasized ? SemanticTokens.Text.primary : SemanticTokens.Text.secondary)
            .textSelection(.enabled)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PrimitiveTokens.Space.xs)
            .padding(.vertical, PrimitiveTokens.Space.xs)
            .background(SemanticTokens.Surface.raisedFill)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PrimitiveTokens.Radius.sm,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PrimitiveTokens.Radius.sm,
                    style: .continuous
                )
                .stroke(SemanticTokens.Border.subtle, lineWidth: PrimitiveTokens.Stroke.subtle)
            }
            .fixedSize(horizontal: false, vertical: true)
    }

    private func advancedMessageBlock(_ text: String) -> some View {
        Text(text)
            .font(PrimitiveTokens.Typography.meta)
            .foregroundStyle(SemanticTokens.Text.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func displayConnectorText(_ text: String) -> String {
        var displayText = text
        let homePath = NSHomeDirectory()
        if !homePath.isEmpty {
            displayText = displayText.replacingOccurrences(of: homePath, with: "~")
        }

        if let repositoryRootPath = mcpConnectorSettingsModel.inspection.repositoryRootPath {
            let repositoryDisplayPath = "…/\(URL(fileURLWithPath: repositoryRootPath).lastPathComponent)"
            displayText = displayText.replacingOccurrences(of: repositoryRootPath, with: repositoryDisplayPath)
        }

        return displayText
    }
}

private enum ConnectorChipTone {
    case neutral
    case accent
    case success
    case warning
    case danger

    var fill: Color {
        switch self {
        case .neutral:
            return SemanticTokens.Surface.raisedFill
        case .accent:
            return SemanticTokens.Accent.primary.opacity(0.12)
        case .success:
            return Color(nsColor: .systemGreen).opacity(0.14)
        case .warning:
            return Color(nsColor: .systemOrange).opacity(0.14)
        case .danger:
            return Color(nsColor: .systemRed).opacity(0.14)
        }
    }

    var border: Color {
        switch self {
        case .neutral:
            return SemanticTokens.Border.subtle
        case .accent:
            return SemanticTokens.Accent.primary.opacity(0.28)
        case .success:
            return Color(nsColor: .systemGreen).opacity(0.34)
        case .warning:
            return Color(nsColor: .systemOrange).opacity(0.34)
        case .danger:
            return Color(nsColor: .systemRed).opacity(0.34)
        }
    }

    var foreground: Color {
        switch self {
        case .neutral:
            return SemanticTokens.Text.primary
        case .accent:
            return SemanticTokens.Accent.primary
        case .success:
            return Color(nsColor: .systemGreen)
        case .warning:
            return Color(nsColor: .systemOrange)
        case .danger:
            return Color(nsColor: .systemRed)
        }
    }
}
