import Combine
import Foundation
import SwiftUI

/// Observable state for the Island UI
class IslandState: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var showPending: Bool = false
    @Published var sessions: [Session] = []
    @Published var pluginStatus: PluginStatus = .unknown
    @Published var showSetupAlert: Bool = false
    
    /// Plugin installation status
    enum PluginStatus {
        case unknown
        case installed
        case notInstalled
        case installFailed(String)
        case opencodeNotFound
        
        var isOk: Bool {
            switch self {
            case .installed:
                return true
            default:
                return false
            }
        }
        
        var statusMessage: String {
            switch self {
            case .unknown:
                return "Checking plugin status..."
            case .installed:
                return "Plugin installed"
            case .notInstalled:
                return "Plugin not installed"
            case .installFailed(let reason):
                return "Installation failed: \(reason)"
            case .opencodeNotFound:
                return "OpenCode not found"
            }
        }
    }
    
    /// Session model representing an OpenCode session
    struct Session: Identifiable {
        let id: String
        var title: String
        let cwd: String
        let model: String
        var status: Status
        var pendingTool: String?
        var pendingToolId: String?
        var permissionType: String?
        var latestMessage: String?
        
        enum Status: String {
            case idle = "Ready"
            case processing = "Processing"
            case waiting = "Waiting"
        }
    }
}
