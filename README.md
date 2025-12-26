<p align="center">
  <img src="https://raw.githubusercontent.com/Karnak19/opencode-island/main/assets/icon.png" width="128" height="128" alt="Opencode Island">
</p>

<h1 align="center">Opencode Island</h1>

<p align="center">
  <strong>Dynamic Island-style notifications for OpenCode CLI</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#development">Development</a> •
  <a href="#license">License</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-15.0+-blue?style=flat-square&logo=apple" alt="macOS 15+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift" alt="Swift 5.9">
  <img src="https://img.shields.io/github/license/Karnak19/opencode-island?style=flat-square" alt="License">
</p>

---

## What is Opencode Island?

Opencode Island is a native macOS menu bar app that brings **Dynamic Island-style notifications** to your [OpenCode](https://opencode.ai) CLI sessions. It eliminates context switching by providing real-time session monitoring directly from your MacBook's notch area.

**Stop switching to terminal.** Stay focused in your IDE while keeping full control over AI actions.

> 🙏 **Heavily inspired by [Claude Island](https://github.com/farouqaldori/claude-island)** by [@farouqaldori](https://github.com/farouqaldori) — the original Dynamic Island experience for Claude Code. This project adapts the concept for OpenCode users.

<p align="center">
  <img src="https://raw.githubusercontent.com/Karnak19/opencode-island/main/assets/demo.gif" width="600" alt="Demo">
</p>

## Features

### 🏝️ Dynamic Island Interface

An elegant overlay that expands from your MacBook's notch area, showing session status without disrupting your workflow.

### 🔄 Live Session Monitoring

Track all active OpenCode sessions in real-time:

- Session name and working directory
- Current status (idle, processing, waiting for approval)
- Visual indicators for each state

### 👀 Approval Awareness

Know instantly when OpenCode needs your attention:

- Visual notification when approval is pending
- Permission type indicator (file write, execute, etc.)
- Approve actions in your terminal

### 🔌 Zero Configuration

Just download, install, and run. The app automatically:

- Detects your OpenCode installation
- Installs the required plugin
- Starts listening for sessions

### ⚙️ oh-my-opencode Config Manager

Visual editor for managing your `oh-my-opencode.json` configuration:

- **Agents Panel**: Enable/disable agents, configure models (Claude Opus 4.5, GPT-5.2, Gemini 3 Pro), adjust temperature and top P
- **Hooks Panel**: Toggle lifecycle hooks like `todo-continuation-enforcer`, `comment-checker`, `context-window-monitor`
- **MCPs Panel**: Enable/disable Model Context Protocol servers (context7, websearch_exa, grep_app)
- **Claude Code Compatibility**: Load configurations from `~/.claude` directory
- **Advanced Panel**: Raw JSON editor with syntax validation for power users

Access the config manager by clicking the gear icon in the expanded island view.

Configuration is stored at `~/.config/opencode/oh-my-opencode.json` and is automatically created on first use.

## Installation

### Download

1. Download the latest `.dmg` from [Releases](https://github.com/Karnak19/opencode-island/releases)
2. Open the DMG and drag **Opencode Island** to Applications
3. Launch the app

That's it! The app will automatically install the OpenCode plugin on first launch.

### Requirements

- macOS 15.0 or later
- [OpenCode CLI](https://opencode.ai) installed

### Manual Plugin Installation

If auto-installation fails, you can install the plugin manually:

```bash
# Create plugin directory
mkdir -p ~/.opencode/plugin

# Download the plugin
curl -o ~/.opencode/plugin/opencode-island.ts \
  https://raw.githubusercontent.com/Karnak19/opencode-island/main/plugin/opencode-island.ts
```

## Usage

### Session States

| State             | Description                         |
| ----------------- | ----------------------------------- |
| 🟢 **Idle**       | Session is ready, waiting for input |
| 🟠 **Processing** | AI is thinking or executing a tool  |
| 🟡 **Waiting**    | Tool approval needed                |

### Interacting with the Island

- **Click the notch area** when sessions are active to expand the island
- **Click a session** to see details and pending approvals
- **Click outside** or the notch again to collapse
- **Menu bar icon** provides quick access when no sessions are active

### Plugin Events

The OpenCode plugin communicates with the app via Unix socket at `~/.opencode-island/socket`, sending events for:

- Session start/end
- Status changes (idle, busy, waiting)
- Tool execution requests
- Permission approvals

## Development

### Prerequisites

- Xcode 15+ or Swift 5.9+
- macOS 15.0+

### Building from Source

```bash
# Clone the repository
git clone https://github.com/Karnak19/opencode-island.git
cd opencode-island

# Build the app
./build.sh

# Run the app
open "dist/Opencode Island.app"
```

### Project Structure

```
opencode-island/
├── Sources/
│   ├── App.swift              # App entry point
│   ├── AppDelegate.swift      # App lifecycle & setup
│   ├── SocketServer.swift     # Unix socket for plugin communication
│   ├── Models/
│   │   ├── IslandState.swift  # Observable state
│   │   └── ConfigModel.swift  # oh-my-opencode.json models
│   ├── Services/
│   │   ├── PluginInstaller.swift  # Auto-installation logic
│   │   └── ConfigManager.swift    # Config persistence
│   ├── Views/
│   │   ├── IslandView.swift       # Main island UI
│   │   ├── CollapsedPillView.swift
│   │   ├── ExpandedContentView.swift
│   │   ├── SessionRowView.swift
│   │   └── SettingsView.swift     # Config manager UI
│   └── Utilities/
│       ├── Theme.swift        # Design system
│       ├── NotchPanel.swift   # Custom window
│       └── EventMonitors.swift
├── plugin/
│   └── opencode-island.ts     # OpenCode plugin
├── Package.swift
├── build.sh
└── oh-my-opencode.example.json  # Example config file
```

### Architecture

The app follows a clean architecture inspired by [Feature-Sliced Design](https://feature-sliced.design/):

- **Models**: Core data structures and observable state
- **Services**: Business logic (plugin installation, socket communication)
- **Views**: SwiftUI components organized by feature
- **Utilities**: Shared helpers and extensions

### Creating a Release

Releases are automated via GitHub Actions. To create a new release:

```bash
# Tag a new version
git tag v1.0.0
git push origin v1.0.0
```

This will:

1. Build the app in release mode
2. Create a DMG with Applications shortcut
3. Create a GitHub Release with the DMG attached

## Troubleshooting

### Plugin not connecting

1. Ensure OpenCode is installed (`~/.opencode` directory exists)
2. Check the plugin is installed: `ls ~/.opencode/plugin/opencode-island.ts`
3. Restart OpenCode after installing the plugin

### Island not appearing

1. Check that Opencode Island is running (look for the terminal icon in menu bar)
2. Try clicking the menu bar icon
3. Start an OpenCode session to trigger the island

### Socket errors

The app creates a socket at `~/.opencode-island/socket`. If there are issues:

```bash
# Remove stale socket
rm -rf ~/.opencode-island/socket

# Restart the app
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

Apache-2.0 License - see [LICENSE.md](LICENSE.md) for details.

---

<p align="center">
  Made with ☕ for the OpenCode community
</p>
