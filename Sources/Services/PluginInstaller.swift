import Foundation
import os.log

private let logger = Logger(subsystem: "com.opencodeisland", category: "PluginInstaller")

/// Handles auto-installation of the OpenCode plugin
enum PluginInstaller {
    
    // MARK: - Types
    
    enum InstallationResult {
        case success
        case alreadyInstalled
        case opencodeNotInstalled
        case copyFailed(Error)
        case pluginResourceMissing
    }
    
    struct InstallationStatus {
        let result: InstallationResult
        let pluginPath: String
        let manualInstructions: String?
        
        var isSuccess: Bool {
            switch result {
            case .success, .alreadyInstalled:
                return true
            default:
                return false
            }
        }
        
        var message: String {
            switch result {
            case .success:
                return "Plugin installed successfully"
            case .alreadyInstalled:
                return "Plugin already installed"
            case .opencodeNotInstalled:
                return "OpenCode not found"
            case .copyFailed(let error):
                return "Installation failed: \(error.localizedDescription)"
            case .pluginResourceMissing:
                return "Plugin resource missing from app bundle"
            }
        }
    }
    
    // MARK: - Paths
    
    private static var opencodeConfigDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".opencode")
    }
    
    private static var opencodePluginDir: URL {
        opencodeConfigDir.appendingPathComponent("plugin")
    }
    
    private static var pluginDestination: URL {
        opencodePluginDir.appendingPathComponent("opencode-island.ts")
    }
    
    // MARK: - Public API
    
    /// Check if OpenCode is installed by looking for ~/.opencode directory
    static func isOpencodeInstalled() -> Bool {
        FileManager.default.fileExists(atPath: opencodeConfigDir.path)
    }
    
    /// Check if our plugin is already installed
    static func isPluginInstalled() -> Bool {
        FileManager.default.fileExists(atPath: pluginDestination.path)
    }
    
    /// Install the plugin, returns installation status
    @discardableResult
    static func installPlugin() -> InstallationStatus {
        logger.info("Starting plugin installation check...")
        
        // Check if OpenCode is installed
        guard isOpencodeInstalled() else {
            logger.warning("OpenCode not installed - ~/.opencode directory not found")
            return InstallationStatus(
                result: .opencodeNotInstalled,
                pluginPath: pluginDestination.path,
                manualInstructions: manualInstructions
            )
        }
        
        // Check if plugin is already installed
        if isPluginInstalled() {
            logger.info("Plugin already installed at \(pluginDestination.path)")
            // Update the plugin if the bundled version is newer
            if let updated = updatePluginIfNeeded() {
                return updated
            }
            return InstallationStatus(
                result: .alreadyInstalled,
                pluginPath: pluginDestination.path,
                manualInstructions: nil
            )
        }
        
        // Get the bundled plugin content
        guard let pluginContent = bundledPluginContent() else {
            logger.error("Plugin resource not found in app bundle")
            return InstallationStatus(
                result: .pluginResourceMissing,
                pluginPath: pluginDestination.path,
                manualInstructions: manualInstructions
            )
        }
        
        // Create plugin directory if needed
        do {
            try FileManager.default.createDirectory(
                at: opencodePluginDir,
                withIntermediateDirectories: true
            )
        } catch {
            logger.error("Failed to create plugin directory: \(error)")
            return InstallationStatus(
                result: .copyFailed(error),
                pluginPath: pluginDestination.path,
                manualInstructions: manualInstructions
            )
        }
        
        // Write the plugin file
        do {
            try pluginContent.write(to: pluginDestination, atomically: true, encoding: .utf8)
            logger.info("Plugin installed successfully to \(pluginDestination.path)")
            return InstallationStatus(
                result: .success,
                pluginPath: pluginDestination.path,
                manualInstructions: nil
            )
        } catch {
            logger.error("Failed to write plugin file: \(error)")
            return InstallationStatus(
                result: .copyFailed(error),
                pluginPath: pluginDestination.path,
                manualInstructions: manualInstructions
            )
        }
    }
    
    // MARK: - Private Helpers
    
    /// Get the plugin content from the app bundle or embedded string
    private static func bundledPluginContent() -> String? {
        // First try to load from bundle resources
        if let bundlePath = Bundle.main.path(forResource: "opencode-island", ofType: "ts") {
            return try? String(contentsOfFile: bundlePath, encoding: .utf8)
        }
        
        // Fallback to embedded plugin content
        return embeddedPluginContent
    }
    
    /// Update plugin if bundled version is different
    private static func updatePluginIfNeeded() -> InstallationStatus? {
        guard let bundledContent = bundledPluginContent() else { return nil }
        guard let installedContent = try? String(contentsOf: pluginDestination, encoding: .utf8) else { return nil }
        
        // Compare content (simple hash comparison)
        if bundledContent.hashValue != installedContent.hashValue {
            logger.info("Updating plugin to newer version...")
            do {
                try bundledContent.write(to: pluginDestination, atomically: true, encoding: .utf8)
                logger.info("Plugin updated successfully")
                return InstallationStatus(
                    result: .success,
                    pluginPath: pluginDestination.path,
                    manualInstructions: nil
                )
            } catch {
                logger.error("Failed to update plugin: \(error)")
                return nil
            }
        }
        
        return nil
    }
    
    /// Manual installation instructions for when auto-install fails
    static var manualInstructions: String {
        """
        Manual Installation Instructions:
        
        1. Ensure OpenCode is installed (https://opencode.ai)
        
        2. Create the plugin directory:
           mkdir -p ~/.opencode/plugin
        
        3. Copy the plugin file:
           The plugin source is available at:
           https://github.com/your-repo/opencode-island/blob/main/plugin/opencode-island.ts
        
        4. Restart OpenCode to load the plugin
        """
    }
    
    // MARK: - Embedded Plugin Content
    
    /// Embedded plugin content as fallback when bundle resource is not available
    private static let embeddedPluginContent = #"""
import type { Plugin } from "@opencode-ai/plugin"
import { connect } from "net"
import { homedir } from "os"
import { join } from "path"

const SOCKET_PATH = join(homedir(), ".opencode-island", "socket")

// Track current session
let currentSessionId: string | null = null
let currentCwd: string | null = null

/**
 * Send event to Opencode Island via Unix socket
 */
function sendEvent(event: {
  type: string
  session_id: string
  payload: Record<string, unknown>
}): Promise<void> {
  return new Promise((resolve) => {
    const socket = connect(SOCKET_PATH)
    
    socket.on("connect", () => {
      const message = JSON.stringify({
        version: "1.0",
        type: event.type,
        timestamp: Date.now(),
        session_id: event.session_id,
        payload: event.payload,
      })
      socket.write(message)
      socket.end()
      resolve()
    })
    
    socket.on("error", (err) => {
      // Socket not available - Island app might not be running
      // Silently ignore
      resolve()
    })
    
    // Timeout after 1 second
    setTimeout(() => {
      socket.destroy()
      resolve()
    }, 1000)
  })
}

/**
 * Opencode Island Plugin
 * Sends session and tool events to the Opencode Island app
 */
export const OpencodeIslandPlugin: Plugin = async ({ directory }) => {
  currentCwd = directory
  
  return {
    // Generic event handler for all events
    event: async ({ event }) => {
      // Session created or updated - extract session info
      if (event.type === "session.created" || event.type === "session.updated") {
        const data = event.properties as { info?: { id?: string; title?: string } }
        if (data.info?.id) {
          const isNew = currentSessionId !== data.info.id
          currentSessionId = data.info.id
          
          // Only send session_start for new sessions
          if (isNew) {
            await sendEvent({
              type: "session_start",
              session_id: data.info.id,
              payload: {
                cwd: currentCwd,
                title: data.info.title || currentCwd?.split("/").pop(),
                model: "unknown",
              },
            })
          } else if (event.type === "session.updated" && data.info.title) {
            // Send session_update for title changes on existing sessions
            await sendEvent({
              type: "session_update",
              session_id: data.info.id,
              payload: {
                title: data.info.title,
              },
            })
          }
        }
      }
      
      // Session idle (finished processing)
      if (event.type === "session.idle" && currentSessionId) {
        await sendEvent({
          type: "session_update",
          session_id: currentSessionId,
          payload: {
            status: "idle",
          },
        })
      }
      
      // Session status update
      if (event.type === "session.status" && currentSessionId) {
        const data = event.properties as { status?: { type?: string } | string }
        const status = typeof data.status === "object" ? data.status?.type : data.status
        if (status) {
          await sendEvent({
            type: "session_update",
            session_id: currentSessionId,
            payload: {
              status: status === "busy" ? "processing" : status,
            },
          })
        }
      }
      
      // Session deleted/ended
      if (event.type === "session.deleted" && currentSessionId) {
        await sendEvent({
          type: "session_end",
          session_id: currentSessionId,
          payload: {},
        })
        currentSessionId = null
      }
      
      // Permission request - this is the actual "waiting for approval" event
      if (event.type === "permission.updated" && currentSessionId) {
        const data = event.properties as {
          id?: string
          type?: string
          title?: string
          metadata?: { command?: string; tool?: string }
          callID?: string
        }
        // permission.updated means user needs to approve something
        await sendEvent({
          type: "session_update",
          session_id: currentSessionId,
          payload: {
            status: "waiting_for_approval",
            tool: data.metadata?.tool || data.type || "permission",
            permission_type: data.type,
            message: data.title,
          },
        })
      }
      
      // Permission replied - user approved or denied
      if (event.type === "permission.replied" && currentSessionId) {
        await sendEvent({
          type: "session_update",
          session_id: currentSessionId,
          payload: {
            status: "processing",
          },
        })
      }
    },
    
    // Tool execution hooks
    "tool.execute.before": async (input) => {
      if (currentSessionId) {
        await sendEvent({
          type: "session_update",
          session_id: currentSessionId,
          payload: {
            status: "processing",
            tool: input.tool,
          },
        })
      }
    },
    
    "tool.execute.after": async (input) => {
      if (currentSessionId) {
        await sendEvent({
          type: "tool_executed",
          session_id: currentSessionId,
          payload: {
            tool: input.tool,
            status: "completed",
          },
        })
      }
    },
  }
}
"""#
}

