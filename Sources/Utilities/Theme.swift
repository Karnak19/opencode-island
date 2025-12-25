import SwiftUI

/// Centralized theme constants for the Opencode Island app
enum Theme {
    
    // MARK: - Colors
    
    enum Colors {
        static let accent = Color(red: 0.85, green: 0.65, blue: 0.55)
        static let background = Color.black
        
        static let statusIdle = Color.green
        static let statusProcessing = accent
        static let statusWaiting = Color.yellow
    }
    
    // MARK: - Dimensions
    
    enum Dimensions {
        /// Main window size
        static let windowSize = CGSize(width: 500, height: 450)
        
        /// Notch detection area
        static let notchSize = CGSize(width: 200, height: 38)
        
        /// Island states
        static let hiddenSize = CGSize(width: 180, height: 32)
        static let collapsedSize = CGSize(width: 310, height: 44)
        static let expandedSize = CGSize(width: 440, height: 380)
        
        /// Corner radii
        static let expandedCornerRadius: CGFloat = 28
        static var collapsedCornerRadius: CGFloat { collapsedSize.height / 2 }
        
        /// Common spacing
        static let sessionRowCornerRadius: CGFloat = 12
        static let iconFrameSize: CGFloat = 50
    }
    
    // MARK: - Animation
    
    enum Animation {
        static let springResponse: Double = 0.4
        static let springDamping: Double = 0.8
        
        static var spring: SwiftUI.Animation {
            .spring(response: springResponse, dampingFraction: springDamping)
        }
    }
    
    // MARK: - Typography
    
    enum Typography {
        static let monospacedBody = Font.system(size: 14, weight: .medium, design: .monospaced)
        static let monospacedCaption = Font.system(size: 12, design: .monospaced)
        static let monospacedSmall = Font.system(size: 11, weight: .medium, design: .monospaced)
        static let monospacedTiny = Font.system(size: 10, design: .monospaced)
    }
}

// MARK: - Permission Helpers

enum PermissionType {
    /// Returns the appropriate SF Symbol icon for a permission type
    static func icon(for permissionType: String?) -> String {
        switch permissionType {
        case "external_directory":
            return "folder.badge.questionmark"
        case "write", "file_write":
            return "doc.badge.ellipsis"
        case "execute", "bash", "shell":
            return "terminal"
        case "read", "file_read":
            return "doc.text.magnifyingglass"
        case "network", "http":
            return "network"
        case "delete", "remove":
            return "trash"
        default:
            return "questionmark.circle"
        }
    }
    
    /// Returns a human-readable label for a permission type
    static func label(for permissionType: String?) -> String {
        switch permissionType {
        case "external_directory":
            return "External path access"
        case "write", "file_write":
            return "File write"
        case "execute", "bash", "shell":
            return "Execute command"
        case "read", "file_read":
            return "File read"
        case "network", "http":
            return "Network access"
        case "delete", "remove":
            return "Delete file"
        default:
            return "Approval needed"
        }
    }
}
