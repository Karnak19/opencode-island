import SwiftUI

/// Alert view shown when plugin installation requires user attention
struct SetupAlertView: View {
    @ObservedObject var state: IslandState
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                statusIcon
                Text(headerTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: { state.showSetupAlert = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Status message
            Text(state.pluginStatus.statusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Content based on status
            switch state.pluginStatus {
            case .installed:
                successContent
            case .opencodeNotFound:
                opencodeNotFoundContent
            case .installFailed(let reason):
                installFailedContent(reason: reason)
            case .notInstalled:
                notInstalledContent
            case .unknown:
                loadingContent
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 300)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Status Icon
    
    @ViewBuilder
    private var statusIcon: some View {
        switch state.pluginStatus {
        case .installed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
        case .opencodeNotFound, .installFailed, .notInstalled:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title2)
        case .unknown:
            ProgressView()
                .scaleEffect(0.8)
        }
    }
    
    private var headerTitle: String {
        switch state.pluginStatus {
        case .installed:
            return "Setup Complete"
        case .opencodeNotFound:
            return "OpenCode Not Found"
        case .installFailed:
            return "Installation Failed"
        case .notInstalled:
            return "Plugin Not Installed"
        case .unknown:
            return "Checking Setup..."
        }
    }
    
    // MARK: - Content Views
    
    private var successContent: some View {
        VStack(spacing: 12) {
            Text("Opencode Island is ready to use!")
                .font(.body)
            
            Text("The plugin has been installed and will automatically connect when you start an OpenCode session.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Got it") {
                state.showSetupAlert = false
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var opencodeNotFoundContent: some View {
        VStack(spacing: 12) {
            Text("OpenCode doesn't appear to be installed on this system.")
                .font(.body)
                .multilineTextAlignment(.center)
            
            Text("Please install OpenCode first, then relaunch Opencode Island.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button("Install OpenCode") {
                    openURL(URL(string: "https://opencode.ai")!)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Dismiss") {
                    state.showSetupAlert = false
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func installFailedContent(reason: String) -> some View {
        VStack(spacing: 12) {
            Text("Automatic installation failed.")
                .font(.body)
            
            Text(reason)
                .font(.caption)
                .foregroundColor(.red)
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            
            manualInstructionsSection
        }
    }
    
    private var notInstalledContent: some View {
        VStack(spacing: 12) {
            Text("The plugin needs to be installed manually.")
                .font(.body)
            
            manualInstructionsSection
        }
    }
    
    private var loadingContent: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Checking plugin installation...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var manualInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Manual Installation:")
                .font(.subheadline.bold())
            
            VStack(alignment: .leading, spacing: 4) {
                instructionRow(number: 1, text: "Create plugin directory:")
                codeBlock("mkdir -p ~/.opencode/plugin")
                
                instructionRow(number: 2, text: "Copy the plugin file from the repo")
                
                instructionRow(number: 3, text: "Restart OpenCode")
            }
            .font(.caption)
            
            HStack(spacing: 12) {
                Button("View on GitHub") {
                    openURL(URL(string: "https://github.com/basile-vernouillet/opencode-island")!)
                }
                .buttonStyle(.bordered)
                
                Button("Retry") {
                    let status = PluginInstaller.installPlugin()
                    updatePluginStatus(from: status)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Dismiss") {
                    state.showSetupAlert = false
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(number).")
                .foregroundColor(.secondary)
            Text(text)
        }
    }
    
    private func codeBlock(_ code: String) -> some View {
        Text(code)
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.1))
            .cornerRadius(4)
            .padding(.leading, 16)
    }
    
    private func updatePluginStatus(from status: PluginInstaller.InstallationStatus) {
        switch status.result {
        case .success, .alreadyInstalled:
            state.pluginStatus = .installed
        case .opencodeNotInstalled:
            state.pluginStatus = .opencodeNotFound
        case .copyFailed(let error):
            state.pluginStatus = .installFailed(error.localizedDescription)
        case .pluginResourceMissing:
            state.pluginStatus = .installFailed("Plugin resource missing from app bundle")
        }
    }
}

