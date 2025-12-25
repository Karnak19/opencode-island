import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var islandWindow: NSPanel?
    private var islandState = IslandState()
    private var clickMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarIcon()
        setupIslandWindow()
        setupClickOutsideMonitor()
        
        // For testing: show pending state after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.islandState.showPending = true
        }
    }
    
    // MARK: - Click Outside to Close
    
    private func setupClickOutsideMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.islandState.isExpanded else { return }
            
            // Check if click is outside the island window
            if let window = self.islandWindow {
                let clickLocation = event.locationInWindow
                let screenLocation = NSEvent.mouseLocation
                let windowFrame = window.frame
                
                if !windowFrame.contains(screenLocation) {
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            self.islandState.isExpanded = false
                        }
                    }
                }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    // MARK: - Menu Bar Icon (for control/fallback)
    
    private func setupMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Opencode Island")
            button.image = image?.withSymbolConfiguration(config)
            button.action = #selector(menuBarClicked)
            button.target = self
        }
    }
    
    @objc private func menuBarClicked() {
        if islandState.isExpanded {
            islandState.isExpanded = false
        } else if islandState.showPending {
            islandState.isExpanded = true
        } else {
            islandState.showPending = true
        }
    }
    
    // MARK: - Dynamic Island Window
    
    private func setupIslandWindow() {
        guard let screen = NSScreen.main else { return }
        
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 450
        
        let screenFrame = screen.frame
        let xPos = screenFrame.midX - (windowWidth / 2)
        let yPos = screenFrame.maxY - windowHeight
        
        let windowRect = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)
        
        let panel = NSPanel(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .mainMenu + 2
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        
        let contentView = NSHostingView(rootView: IslandView(state: islandState))
        panel.contentView = contentView
        
        panel.orderFrontRegardless()
        
        islandWindow = panel
    }
}

// MARK: - Island State

class IslandState: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var showPending: Bool = false
    @Published var sessions: [Session] = []
    
    struct Session: Identifiable {
        let id = UUID()
        let title: String
        var status: Status
        
        enum Status: String {
            case idle = "Idle"
            case processing = "Processing"
            case waiting = "Waiting"
        }
    }
}

// MARK: - Flat Top Shape (straight top, rounded bottom)

struct FlatTopShape: Shape {
    var bottomRadius: CGFloat
    
    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = rect.width
        let h = rect.height
        let br = min(bottomRadius, w / 2, h / 2)
        
        // Start at top-left (flat, no radius)
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Top edge (straight)
        path.addLine(to: CGPoint(x: w, y: 0))
        
        // Right edge down to bottom-right corner
        path.addLine(to: CGPoint(x: w, y: h - br))
        
        // Bottom-right rounded corner
        path.addQuadCurve(
            to: CGPoint(x: w - br, y: h),
            control: CGPoint(x: w, y: h)
        )
        
        // Bottom edge
        path.addLine(to: CGPoint(x: br, y: h))
        
        // Bottom-left rounded corner
        path.addQuadCurve(
            to: CGPoint(x: 0, y: h - br),
            control: CGPoint(x: 0, y: h)
        )
        
        // Left edge back to top
        path.addLine(to: CGPoint(x: 0, y: 0))
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Island View

struct IslandView: View {
    @ObservedObject var state: IslandState
    @State private var isHovering: Bool = false
    
    // Colors
    private let accentColor = Color(red: 0.85, green: 0.65, blue: 0.55)
    private let bgColor = Color.black
    
    // Dimensions
    private let hiddenWidth: CGFloat = 180
    private let hiddenHeight: CGFloat = 32
    private let collapsedWidth: CGFloat = 310
    private let collapsedHeight: CGFloat = 44
    private let expandedWidth: CGFloat = 440
    private let expandedHeight: CGFloat = 380
    
    private var currentWidth: CGFloat {
        if state.isExpanded { return expandedWidth }
        else if state.showPending { return collapsedWidth }
        else { return hiddenWidth }
    }
    
    private var currentHeight: CGFloat {
        if state.isExpanded { return expandedHeight }
        else if state.showPending { return collapsedHeight }
        else { return hiddenHeight }
    }
    
    private var bottomCornerRadius: CGFloat {
        if state.isExpanded { return 28 }
        else { return collapsedHeight / 2 }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Content based on state
                if state.isExpanded {
                    expandedContent
                } else if state.showPending {
                    collapsedPill
                }
            }
            .frame(width: currentWidth, height: currentHeight)
            .background(
                FlatTopShape(bottomRadius: bottomCornerRadius)
                    .fill(bgColor)
                    .shadow(color: .black.opacity(state.showPending || state.isExpanded ? 0.5 : 0), radius: 20, y: 10)
            )
            .clipShape(FlatTopShape(bottomRadius: bottomCornerRadius))
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if state.isExpanded {
                        state.isExpanded = false
                    } else if state.showPending {
                        state.isExpanded = true
                    }
                }
            }
            .onHover { hovering in
                isHovering = hovering
            }
            .scaleEffect(isHovering && state.showPending && !state.isExpanded ? 1.02 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.isExpanded)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.showPending)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Collapsed Pill
    
    private var collapsedPill: some View {
        HStack(spacing: 0) {
            Image(systemName: "apple.terminal.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(accentColor)
                .frame(width: 50, height: collapsedHeight)
            
            Spacer()
            
            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(accentColor)
                .frame(width: 50, height: collapsedHeight)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Expanded Content
    
    private var expandedContent: some View {
        VStack(spacing: 0) {
            expandedHeader
            
            if state.sessions.isEmpty {
                emptyState
            } else {
                sessionsList
            }
            
            Spacer()
            footerBar
        }
    }
    
    private var expandedHeader: some View {
        HStack(spacing: 0) {
            Image(systemName: "apple.terminal.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(accentColor)
                .frame(width: 50, height: collapsedHeight)
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    state.isExpanded = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(accentColor.opacity(0.6))
            }
            .buttonStyle(.plain)
            .frame(width: 50, height: collapsedHeight)
        }
        .padding(.horizontal, 4)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "terminal")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(accentColor.opacity(0.3))
            
            Text("No active sessions")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
            
            Text("Start an OpenCode session\nto see it here")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var sessionsList: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(state.sessions) { session in
                    sessionRow(session)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
    
    private func sessionRow(_ session: IslandState.Session) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor(for: session.status))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(session.status.rawValue)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(session.status == .processing ? accentColor : .white.opacity(0.4))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func statusColor(for status: IslandState.Session.Status) -> Color {
        switch status {
        case .idle: return .white.opacity(0.3)
        case .processing: return accentColor
        case .waiting: return .yellow
        }
    }
    
    private var footerBar: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("Quit")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}
