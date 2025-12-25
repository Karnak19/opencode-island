import AppKit

/// Custom NSPanel for the Dynamic Island overlay
/// Floating panel that can pass through mouse events when collapsed
class NotchPanel: NSPanel {
    
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Floating panel behavior
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        
        // Transparent
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        
        // Window behavior
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        level = .mainMenu + 3
        
        // CRITICAL: Start with ignoring mouse events
        // This allows clicks to pass through to menu bar and apps
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = false
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
