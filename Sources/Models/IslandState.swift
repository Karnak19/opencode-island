import Combine
import Foundation
import SwiftUI

/// Observable state for the Island UI
class IslandState: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var showPending: Bool = false
    @Published var sessions: [Session] = []
    
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
