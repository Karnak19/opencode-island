import Foundation

class ConfigManager: ObservableObject {
    @Published var config: OhMyOpencodeConfig
    @Published var isInstalled: Bool = false

    private let configURL: URL

    init() {
        // Determine config file location
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configDir = homeDir.appendingPathComponent(".config/opencode")
        self.configURL = configDir.appendingPathComponent("oh-my-opencode.json")

        // Check if config exists and load it
        if let loadedConfig = ConfigManager.loadConfig(from: configURL) {
            self.config = loadedConfig
            self.isInstalled = true
        } else {
            // oh-my-opencode not installed - just load defaults in memory
            self.config = OhMyOpencodeConfig.defaultConfig()
            self.isInstalled = false
        }
    }

    // MARK: - Load Configuration
    private static func loadConfig(from url: URL) -> OhMyOpencodeConfig? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let config = try decoder.decode(OhMyOpencodeConfig.self, from: data)
            return config
        } catch {
            print("Error loading config from \(url.path): \(error)")
            return nil
        }
    }

    // MARK: - Save Configuration
    func saveConfig() {
        // Only save if oh-my-opencode is installed
        guard isInstalled else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)

            try data.write(to: configURL, options: .atomic)
            print("Config saved successfully to \(configURL.path)")
        } catch {
            print("Error saving config to \(configURL.path): \(error)")
        }
    }

    // MARK: - Reset to Defaults
    func resetToDefaults() {
        config = OhMyOpencodeConfig.defaultConfig()
        saveConfig()
    }

    // MARK: - Config Path
    var configPath: String {
        return configURL.path
    }

    // MARK: - Agent Helpers
    func toggleAgent(_ agentName: String) {
        if var agentConfig = config.agents[agentName] {
            agentConfig.enabled.toggle()
            config.agents[agentName] = agentConfig
            saveConfig()
        }
    }

    func updateAgentModel(_ agentName: String, model: String?) {
        if var agentConfig = config.agents[agentName] {
            agentConfig.modelOverride = model
            config.agents[agentName] = agentConfig
            saveConfig()
        }
    }

    func updateAgentTemperature(_ agentName: String, temperature: Double?) {
        if var agentConfig = config.agents[agentName] {
            agentConfig.temperature = temperature
            config.agents[agentName] = agentConfig
            saveConfig()
        }
    }

    func updateAgentTopP(_ agentName: String, topP: Double?) {
        if var agentConfig = config.agents[agentName] {
            agentConfig.topP = topP
            config.agents[agentName] = agentConfig
            saveConfig()
        }
    }

    // MARK: - Hook Helpers
    func toggleHook(_ hookName: String) {
        if var hookConfig = config.hooks[hookName] {
            hookConfig.enabled.toggle()
            config.hooks[hookName] = hookConfig
            saveConfig()
        }
    }

    // MARK: - MCP Helpers
    func toggleMCP(_ mcpName: String) {
        if var mcpConfig = config.mcps[mcpName] {
            mcpConfig.enabled.toggle()
            config.mcps[mcpName] = mcpConfig
            saveConfig()
        }
    }

    // MARK: - Claude Code Compatibility Helpers
    func toggleClaudeCodeFeature(_ keyPath: WritableKeyPath<ClaudeCodeCompatibility, Bool>) {
        config.claudeCodeCompatibility[keyPath: keyPath].toggle()
        saveConfig()
    }
}
