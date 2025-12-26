import SwiftUI

struct SettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var selectedTab: SettingsTab = .agents
    @State private var showRawJSON: Bool = false
    @State private var rawJSONText: String = ""
    @State private var jsonError: String?

    enum SettingsTab: String, CaseIterable {
        case agents = "Agents"
        case hooks = "Hooks"
        case mcps = "MCPs"
        case compatibility = "Claude Code"
        case advanced = "Advanced"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            if !configManager.configExists {
                // Show config creation prompt
                configNotExistsView
            } else {
                // Tab Bar
                tabBarView

                Divider()

                // Content Area
                ScrollView {
                    contentView
                        .padding()
                }

                Divider()

                // Footer
                footerView
            }
        }
        .frame(width: 700, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 24))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("oh-my-opencode Configuration")
                    .font(.title2.bold())
                Text(configManager.configPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Config Not Exists View
    private var configNotExistsView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("oh-my-opencode Not Configured")
                    .font(.title2.bold())

                Text("Configuration file not found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("oh-my-opencode is an optional configuration layer for OpenCode.")
                    .multilineTextAlignment(.center)

                Text("Only create this configuration if you want to:")
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Customize agent behavior and models", systemImage: "person.3.fill")
                    Label("Enable lifecycle hooks", systemImage: "link.circle.fill")
                    Label("Configure MCP servers", systemImage: "server.rack")
                    Label("Load Claude Code compatibility features", systemImage: "arrow.triangle.2.circlepath")
                }
                .font(.callout)
            }
            .frame(maxWidth: 500)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Button(action: {
                configManager.createConfigFile()
            }) {
                Label("Create oh-my-opencode Configuration", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("This will create: \(configManager.configPath)")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
    }

    // MARK: - Tab Bar
    private var tabBarView: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: iconForTab(tab))
                            .font(.system(size: 18))
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
                    .foregroundColor(selectedTab == tab ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Content View
    @ViewBuilder
    private var contentView: View {
        switch selectedTab {
        case .agents:
            agentsPanel
        case .hooks:
            hooksPanel
        case .mcps:
            mcpsPanel
        case .compatibility:
            compatibilityPanel
        case .advanced:
            advancedPanel
        }
    }

    // MARK: - Agents Panel
    private var agentsPanel: View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Agent Configuration")
                .font(.headline)

            Text("Configure individual agents with custom models and parameters")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(configManager.config.agents.keys.sorted(), id: \.self) { agentName in
                agentConfigRow(agentName: agentName)
                Divider()
            }
        }
    }

    private func agentConfigRow(agentName: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Toggle(isOn: Binding(
                    get: { configManager.config.agents[agentName]?.enabled ?? false },
                    set: { _ in configManager.toggleAgent(agentName) }
                )) {
                    Text(agentName)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                }

                Spacer()
            }

            if configManager.config.agents[agentName]?.enabled == true {
                VStack(alignment: .leading, spacing: 12) {
                    // Model Override
                    HStack {
                        Text("Model:")
                            .frame(width: 100, alignment: .leading)
                            .foregroundColor(.secondary)

                        Picker("", selection: Binding(
                            get: { configManager.config.agents[agentName]?.modelOverride },
                            set: { newValue in
                                configManager.updateAgentModel(agentName, model: newValue)
                            }
                        )) {
                            Text("Default").tag(nil as String?)
                            ForEach(AIModel.allCases) { model in
                                Text(model.displayName).tag(model.rawValue as String?)
                            }
                        }
                        .frame(width: 250)
                    }

                    // Temperature
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Temperature:")
                                .frame(width: 100, alignment: .leading)
                                .foregroundColor(.secondary)

                            Slider(
                                value: Binding(
                                    get: { configManager.config.agents[agentName]?.temperature ?? 1.0 },
                                    set: { newValue in
                                        configManager.updateAgentTemperature(agentName, temperature: newValue)
                                    }
                                ),
                                in: 0.0...2.0,
                                step: 0.1
                            )

                            Text(String(format: "%.1f", configManager.config.agents[agentName]?.temperature ?? 1.0))
                                .frame(width: 40)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Top P
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Top P:")
                                .frame(width: 100, alignment: .leading)
                                .foregroundColor(.secondary)

                            Slider(
                                value: Binding(
                                    get: { configManager.config.agents[agentName]?.topP ?? 1.0 },
                                    set: { newValue in
                                        configManager.updateAgentTopP(agentName, topP: newValue)
                                    }
                                ),
                                in: 0.0...1.0,
                                step: 0.05
                            )

                            Text(String(format: "%.2f", configManager.config.agents[agentName]?.topP ?? 1.0))
                                .frame(width: 40)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Hooks Panel
    private var hooksPanel: View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hook Configuration")
                .font(.headline)

            Text("Enable or disable lifecycle hooks")
                .font(.subheadline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(configManager.config.hooks.keys.sorted(), id: \.self) { hookName in
                    hookToggleRow(hookName: hookName)
                }
            }
        }
    }

    private func hookToggleRow(hookName: String) -> some View {
        HStack {
            Toggle(isOn: Binding(
                get: { configManager.config.hooks[hookName]?.enabled ?? false },
                set: { _ in configManager.toggleHook(hookName) }
            )) {
                Text(hookName)
                    .font(.system(size: 12, design: .monospaced))
            }
            .toggleStyle(.switch)

            Spacer()
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }

    // MARK: - MCPs Panel
    private var mcpsPanel: View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MCP Configuration")
                .font(.headline)

            Text("Enable or disable Model Context Protocol servers")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                ForEach(configManager.config.mcps.keys.sorted(), id: \.self) { mcpName in
                    mcpToggleRow(mcpName: mcpName)
                }
            }
        }
    }

    private func mcpToggleRow(mcpName: String) -> some View {
        HStack {
            Image(systemName: configManager.config.mcps[mcpName]?.enabled == true ? "checkmark.circle.fill" : "circle")
                .foregroundColor(configManager.config.mcps[mcpName]?.enabled == true ? .green : .secondary)
                .font(.title3)

            Toggle(isOn: Binding(
                get: { configManager.config.mcps[mcpName]?.enabled ?? false },
                set: { _ in configManager.toggleMCP(mcpName) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mcpName)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    Text("MCP Server")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Compatibility Panel
    private var compatibilityPanel: View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Claude Code Compatibility")
                .font(.headline)

            Text("Load configurations from ~/.claude directory")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                compatibilityToggle(
                    title: "Load MCP from ~/.claude",
                    description: "Import MCP server configurations",
                    keyPath: \.loadMCPFromClaude
                )

                compatibilityToggle(
                    title: "Load commands",
                    description: "Import custom slash commands",
                    keyPath: \.loadCommands
                )

                compatibilityToggle(
                    title: "Load skills",
                    description: "Import skill definitions",
                    keyPath: \.loadSkills
                )

                compatibilityToggle(
                    title: "Load agents",
                    description: "Import agent configurations",
                    keyPath: \.loadAgents
                )

                compatibilityToggle(
                    title: "Load hooks",
                    description: "Import lifecycle hooks",
                    keyPath: \.loadHooks
                )
            }
        }
    }

    private func compatibilityToggle(title: String, description: String, keyPath: WritableKeyPath<ClaudeCodeCompatibility, Bool>) -> some View {
        HStack {
            Image(systemName: configManager.config.claudeCodeCompatibility[keyPath: keyPath] ? "checkmark.circle.fill" : "circle")
                .foregroundColor(configManager.config.claudeCodeCompatibility[keyPath: keyPath] ? .green : .secondary)
                .font(.title3)

            Toggle(isOn: Binding(
                get: { configManager.config.claudeCodeCompatibility[keyPath: keyPath] },
                set: { _ in configManager.toggleClaudeCodeFeature(keyPath) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)

            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Advanced Panel
    private var advancedPanel: View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced Configuration")
                .font(.headline)

            Text("Edit raw JSON configuration (for power users)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if showRawJSON {
                rawJSONEditor
            } else {
                Button("Show Raw JSON Editor") {
                    loadRawJSON()
                    showRawJSON = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var rawJSONEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Raw JSON")
                    .font(.headline)

                Spacer()

                Button("Hide Editor") {
                    showRawJSON = false
                    jsonError = nil
                }
                .buttonStyle(.bordered)
            }

            if let error = jsonError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }

            TextEditor(text: $rawJSONText)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 300)
                .border(Color.secondary.opacity(0.3), width: 1)
                .cornerRadius(4)

            HStack {
                Button("Validate JSON") {
                    validateJSON()
                }
                .buttonStyle(.bordered)

                Button("Apply Changes") {
                    applyRawJSON()
                }
                .buttonStyle(.borderedProminent)
                .disabled(jsonError != nil)

                Spacer()

                Button("Reload from File") {
                    loadRawJSON()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack {
            Button("Reset to Defaults") {
                configManager.resetToDefaults()
            }
            .buttonStyle(.bordered)

            Spacer()

            Text("Changes are saved automatically")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Helper Functions
    private func iconForTab(_ tab: SettingsTab) -> String {
        switch tab {
        case .agents: return "person.3.fill"
        case .hooks: return "link.circle.fill"
        case .mcps: return "server.rack"
        case .compatibility: return "arrow.triangle.2.circlepath"
        case .advanced: return "chevron.left.forwardslash.chevron.right"
        }
    }

    private func loadRawJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(configManager.config),
           let jsonString = String(data: data, encoding: .utf8) {
            rawJSONText = jsonString
            jsonError = nil
        }
    }

    private func validateJSON() {
        guard let data = rawJSONText.data(using: .utf8) else {
            jsonError = "Invalid text encoding"
            return
        }

        do {
            _ = try JSONDecoder().decode(OhMyOpencodeConfig.self, from: data)
            jsonError = nil
        } catch {
            jsonError = "JSON validation failed: \(error.localizedDescription)"
        }
    }

    private func applyRawJSON() {
        guard let data = rawJSONText.data(using: .utf8) else {
            jsonError = "Invalid text encoding"
            return
        }

        do {
            let newConfig = try JSONDecoder().decode(OhMyOpencodeConfig.self, from: data)
            configManager.config = newConfig
            configManager.saveConfig()
            jsonError = nil
        } catch {
            jsonError = "Failed to apply changes: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(configManager: ConfigManager())
    }
}
