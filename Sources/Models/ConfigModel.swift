import Foundation

// MARK: - Root Configuration Model
struct OhMyOpencodeConfig: Codable {
    var agents: [String: AgentConfig]
    var hooks: [String: HookConfig]
    var mcps: [String: MCPConfig]
    var claudeCodeCompatibility: ClaudeCodeCompatibility

    enum CodingKeys: String, CodingKey {
        case agents
        case hooks
        case mcps
        case claudeCodeCompatibility = "claude_code_compatibility"
    }

    static func defaultConfig() -> OhMyOpencodeConfig {
        return OhMyOpencodeConfig(
            agents: Self.defaultAgents(),
            hooks: Self.defaultHooks(),
            mcps: Self.defaultMCPs(),
            claudeCodeCompatibility: ClaudeCodeCompatibility.default()
        )
    }

    static func defaultAgents() -> [String: AgentConfig] {
        let agentNames = [
            "OmO",
            "oracle",
            "librarian",
            "explore",
            "frontend-ui-ux-engineer",
            "document-writer",
            "multimodal-looker"
        ]

        var agents: [String: AgentConfig] = [:]
        for name in agentNames {
            agents[name] = AgentConfig(
                enabled: true,
                modelOverride: nil,
                temperature: nil,
                topP: nil
            )
        }
        return agents
    }

    static func defaultHooks() -> [String: HookConfig] {
        let hookNames = [
            "todo-continuation-enforcer",
            "comment-checker",
            "context-window-monitor",
            "session-recovery",
            "code-quality-checker",
            "dependency-tracker",
            "security-scanner",
            "performance-monitor",
            "test-coverage-enforcer",
            "git-commit-validator",
            "documentation-enforcer",
            "error-handler",
            "state-saver",
            "auto-formatter",
            "import-organizer"
        ]

        var hooks: [String: HookConfig] = [:]
        for name in hookNames {
            hooks[name] = HookConfig(enabled: false)
        }
        return hooks
    }

    static func defaultMCPs() -> [String: MCPConfig] {
        let mcpNames = ["context7", "websearch_exa", "grep_app"]

        var mcps: [String: MCPConfig] = [:]
        for name in mcpNames {
            mcps[name] = MCPConfig(enabled: false)
        }
        return mcps
    }
}

// MARK: - Agent Configuration
struct AgentConfig: Codable {
    var enabled: Bool
    var modelOverride: String?
    var temperature: Double?
    var topP: Double?

    enum CodingKeys: String, CodingKey {
        case enabled
        case modelOverride = "model_override"
        case temperature
        case topP = "top_p"
    }
}

// MARK: - Hook Configuration
struct HookConfig: Codable {
    var enabled: Bool
}

// MARK: - MCP Configuration
struct MCPConfig: Codable {
    var enabled: Bool
}

// MARK: - Claude Code Compatibility
struct ClaudeCodeCompatibility: Codable {
    var loadMCPFromClaude: Bool
    var loadCommands: Bool
    var loadSkills: Bool
    var loadAgents: Bool
    var loadHooks: Bool

    enum CodingKeys: String, CodingKey {
        case loadMCPFromClaude = "load_mcp_from_claude"
        case loadCommands = "load_commands"
        case loadSkills = "load_skills"
        case loadAgents = "load_agents"
        case loadHooks = "load_hooks"
    }

    static func `default`() -> ClaudeCodeCompatibility {
        return ClaudeCodeCompatibility(
            loadMCPFromClaude: false,
            loadCommands: false,
            loadSkills: false,
            loadAgents: false,
            loadHooks: false
        )
    }
}

// MARK: - Model Options
enum AIModel: String, CaseIterable, Identifiable {
    case claudeOpus45 = "claude-opus-4-5"
    case gpt52 = "gpt-5.2"
    case gemini3Pro = "gemini-3-pro"
    case claudeSonnet4 = "claude-sonnet-4"
    case gpt4Turbo = "gpt-4-turbo"
    case gemini2Ultra = "gemini-2-ultra"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeOpus45: return "Claude Opus 4.5"
        case .gpt52: return "GPT-5.2"
        case .gemini3Pro: return "Gemini 3 Pro"
        case .claudeSonnet4: return "Claude Sonnet 4"
        case .gpt4Turbo: return "GPT-4 Turbo"
        case .gemini2Ultra: return "Gemini 2 Ultra"
        }
    }
}
