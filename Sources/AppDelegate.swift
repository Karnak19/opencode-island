import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var islandWindow: NotchPanel?
    private var islandState = IslandState()
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarIcon()
        setupIslandWindow()
        setupEventMonitors()
        setupSocketServer()
    }
    
    // MARK: - Socket Server
    
    private func setupSocketServer() {
        SocketServer.shared.onEvent = { [weak self] event in
            self?.handlePluginEvent(event)
        }
        SocketServer.shared.start()
    }
    
    private func handlePluginEvent(_ event: PluginEvent) {
        switch event.type {
        case .sessionStart:
            // Add new session
            let session = IslandState.Session(
                id: event.sessionId,
                title: event.payload.cwd?.components(separatedBy: "/").last ?? "Session",
                cwd: event.payload.cwd ?? "",
                model: event.payload.model ?? "unknown",
                status: .idle
            )
            islandState.sessions.append(session)
            islandState.showPending = true
            
        case .sessionEnd:
            // Remove session
            islandState.sessions.removeAll { $0.id == event.sessionId }
            if islandState.sessions.isEmpty {
                islandState.showPending = false
                islandState.isExpanded = false
            }
            
        case .sessionUpdate:
            // Update session status
            if let index = islandState.sessions.firstIndex(where: { $0.id == event.sessionId }) {
                if let status = event.payload.status {
                    switch status {
                    case "processing", "running_tool":
                        islandState.sessions[index].status = .processing
                    case "waiting_for_input":
                        islandState.sessions[index].status = .waiting
                    default:
                        islandState.sessions[index].status = .idle
                    }
                }
            }
            
        case .toolApprovalNeeded:
            // Show approval request
            if let index = islandState.sessions.firstIndex(where: { $0.id == event.sessionId }) {
                islandState.sessions[index].status = .waiting
                islandState.sessions[index].pendingTool = event.payload.tool
                islandState.sessions[index].pendingToolId = event.payload.toolUseId
            }
            // Expand to show approval UI
            islandState.showPending = true
            islandState.isExpanded = true
            
        case .toolExecuted:
            // Tool finished
            if let index = islandState.sessions.firstIndex(where: { $0.id == event.sessionId }) {
                islandState.sessions[index].status = .processing
                islandState.sessions[index].pendingTool = nil
                islandState.sessions[index].pendingToolId = nil
            }
            
        case .event:
            // Generic event - update status if provided
            if let index = islandState.sessions.firstIndex(where: { $0.id == event.sessionId }),
               let status = event.payload.status {
                switch status {
                case "processing":
                    islandState.sessions[index].status = .processing
                case "idle":
                    islandState.sessions[index].status = .idle
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Menu Bar Icon
    
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
    
    // MARK: - Island Window
    
    private func setupIslandWindow() {
        guard let screen = NSScreen.main else { return }
        
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 450
        
        let screenFrame = screen.frame
        let xPos = screenFrame.midX - (windowWidth / 2)
        let yPos = screenFrame.maxY - windowHeight
        
        let windowRect = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)
        
        let panel = NotchPanel(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        let contentView = NSHostingView(rootView: IslandView(state: islandState))
        panel.contentView = contentView
        panel.orderFrontRegardless()
        
        islandWindow = panel
        
        // Toggle ignoresMouseEvents based on expanded state
        islandState.$isExpanded
            .receive(on: DispatchQueue.main)
            .sink { [weak panel] isExpanded in
                // When expanded, accept mouse events (for buttons)
                // When collapsed, ignore mouse events (clicks pass through)
                panel?.ignoresMouseEvents = !isExpanded
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Event Monitors
    
    private func setupEventMonitors() {
        // Monitor mouse movement for hover detection
        EventMonitors.shared.mouseLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.handleMouseMove(at: location)
            }
            .store(in: &cancellables)
        
        // Monitor clicks for open/close
        EventMonitors.shared.mouseDown
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleMouseDown(event)
            }
            .store(in: &cancellables)
    }
    
    private func handleMouseMove(at point: CGPoint) {
        // Could add hover effects here
    }
    
    private func handleMouseDown(_ event: NSEvent) {
        let point = NSEvent.mouseLocation
        
        if islandState.isExpanded {
            // Check if click is outside the expanded panel
            if !isPointInIsland(point) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    islandState.isExpanded = false
                }
            }
        } else if islandState.showPending {
            // Check if click is on the collapsed pill
            if isPointInIsland(point) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    islandState.isExpanded = true
                }
            }
        }
    }
    
    private func isPointInIsland(_ point: CGPoint) -> Bool {
        guard let screen = NSScreen.main else { return false }
        
        let screenFrame = screen.frame
        let width: CGFloat
        let height: CGFloat
        
        if islandState.isExpanded {
            width = 440
            height = 380
        } else if islandState.showPending {
            width = 310
            height = 44
        } else {
            return false
        }
        
        // Island is centered at top of screen
        let islandRect = CGRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.maxY - height,
            width: width,
            height: height
        )
        
        return islandRect.contains(point)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        EventMonitors.shared.stop()
        SocketServer.shared.stop()
    }
}

// MARK: - Notch Panel (Click-through window)

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

// MARK: - Event Monitor

class EventMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent) -> Void
    
    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit {
        stop()
    }
    
    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handler(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handler(event)
            return event
        }
    }
    
    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}

// MARK: - Event Monitors Singleton

class EventMonitors {
    static let shared = EventMonitors()
    
    let mouseLocation = CurrentValueSubject<CGPoint, Never>(.zero)
    let mouseDown = PassthroughSubject<NSEvent, Never>()
    
    private var mouseMoveMonitor: EventMonitor?
    private var mouseDownMonitor: EventMonitor?
    
    private init() {
        setupMonitors()
    }
    
    private func setupMonitors() {
        mouseMoveMonitor = EventMonitor(mask: .mouseMoved) { [weak self] _ in
            self?.mouseLocation.send(NSEvent.mouseLocation)
        }
        mouseMoveMonitor?.start()
        
        mouseDownMonitor = EventMonitor(mask: .leftMouseDown) { [weak self] event in
            self?.mouseDown.send(event)
        }
        mouseDownMonitor?.start()
    }
    
    func stop() {
        mouseMoveMonitor?.stop()
        mouseDownMonitor?.stop()
    }
}

// MARK: - Island State

class IslandState: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var showPending: Bool = false
    @Published var sessions: [Session] = []
    
    struct Session: Identifiable {
        let id: String  // Session ID from OpenCode
        let title: String
        let cwd: String
        let model: String
        var status: Status
        var pendingTool: String?
        var pendingToolId: String?
        
        enum Status: String {
            case idle = "Idle"
            case processing = "Processing"
            case waiting = "Waiting"
        }
    }
    
    func approveToolUse(sessionId: String) {
        if let session = sessions.first(where: { $0.id == sessionId }),
           let toolId = session.pendingToolId {
            SocketServer.shared.respondToApproval(toolUseId: toolId, allow: true)
        }
    }
    
    func denyToolUse(sessionId: String) {
        if let session = sessions.first(where: { $0.id == sessionId }),
           let toolId = session.pendingToolId {
            SocketServer.shared.respondToApproval(toolUseId: toolId, allow: false)
        }
    }
}

// MARK: - Flat Top Shape

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
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: h - br))
        path.addQuadCurve(to: CGPoint(x: w - br, y: h), control: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: br, y: h))
        path.addQuadCurve(to: CGPoint(x: 0, y: h - br), control: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Island View

struct IslandView: View {
    @ObservedObject var state: IslandState
    @State private var isHovering: Bool = false
    
    private let accentColor = Color(red: 0.85, green: 0.65, blue: 0.55)
    private let bgColor = Color.black
    
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
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.isExpanded)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.showPending)
            
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
