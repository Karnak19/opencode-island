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
        print("[Island] Received event: \(event.type.rawValue) for session \(event.sessionId)")
        print("[Island] Current sessions: \(islandState.sessions.map { "\($0.id.prefix(8)):\($0.title)" })")
        switch event.type {
        case .sessionStart:
            // Check if session already exists (update it) or add new
            if let index = islandState.sessions.firstIndex(where: { $0.id == event.sessionId }) {
                print("[Island] Updating existing session at index \(index)")
                // Update existing session - also update title if provided
                islandState.sessions[index].status = .idle
                if let title = event.payload.title {
                    islandState.sessions[index].title = title
                }
            } else {
                print("[Island] Adding new session with id \(event.sessionId)")
                // Add new session
                let title = event.payload.title ?? event.payload.cwd?.components(separatedBy: "/").last ?? "Session"
                let session = IslandState.Session(
                    id: event.sessionId,
                    title: title,
                    cwd: event.payload.cwd ?? "",
                    model: event.payload.model ?? "unknown",
                    status: .idle
                )
                islandState.sessions.append(session)
            }
            // Don't auto-expand, just show pill if any session is active (not idle)
            updateIslandVisibility()
            
        case .sessionEnd:
            // Remove session
            islandState.sessions.removeAll { $0.id == event.sessionId }
            
        case .sessionUpdate:
            // Update session status
            if let index = islandState.sessions.firstIndex(where: { $0.id == event.sessionId }) {
                if let status = event.payload.status {
                    switch status {
                    case "processing", "running_tool":
                        islandState.sessions[index].status = .processing
                        islandState.sessions[index].permissionType = nil
                    case "waiting_for_input", "waiting_for_approval":
                        islandState.sessions[index].status = .waiting
                        islandState.sessions[index].pendingTool = event.payload.tool
                        islandState.sessions[index].permissionType = event.payload.permissionType
                    default:
                        islandState.sessions[index].status = .idle
                        islandState.sessions[index].permissionType = nil
                    }
                }
                if let message = event.payload.message {
                    islandState.sessions[index].latestMessage = message
                }
            }
            
        case .toolExecuted:
            // Tool finished
            if let index = islandState.sessions.firstIndex(where: { $0.id == event.sessionId }) {
                islandState.sessions[index].status = .processing
                islandState.sessions[index].pendingTool = nil
                islandState.sessions[index].pendingToolId = nil
                islandState.sessions[index].permissionType = nil
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
        
        // Update visibility after any event
        updateIslandVisibility()
    }
    
    private func updateIslandVisibility() {
        // Show pill only when there's active work (processing or waiting)
        let hasActiveWork = islandState.sessions.contains { $0.status != .idle }
        islandState.showPending = hasActiveWork
        
        // Auto-collapse only if no sessions at all
        if islandState.sessions.isEmpty {
            islandState.isExpanded = false
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
        // Toggle expanded state if there are sessions
        if !islandState.sessions.isEmpty {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                islandState.isExpanded.toggle()
            }
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
            // If click is on notch area, toggle closed
            // If click is outside the panel, also close
            if isPointInNotchArea(point) || !isPointInIsland(point) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    islandState.isExpanded = false
                }
            }
        } else {
            // Check if click is on the notch area (even when pill is hidden)
            if isPointInNotchArea(point) && !islandState.sessions.isEmpty {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    islandState.isExpanded = true
                }
            }
        }
    }
    
    private func isPointInNotchArea(_ point: CGPoint) -> Bool {
        guard let screen = NSScreen.main else { return false }
        
        let screenFrame = screen.frame
        // Notch area: roughly 200pt wide, 32pt tall, centered at top
        let notchWidth: CGFloat = 200
        let notchHeight: CGFloat = 38
        
        let notchRect = CGRect(
            x: screenFrame.midX - notchWidth / 2,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
        
        return notchRect.contains(point)
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
        var title: String
        let cwd: String
        let model: String
        var status: Status
        var pendingTool: String?
        var pendingToolId: String?
        var permissionType: String?
        var latestMessage: String?
        
        enum Status: String {
            case idle = "Idle"
            case processing = "Processing"
            case waiting = "Waiting"
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

// MARK: - Pulse Animation

struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.5 : 1.0)
            .opacity(isPulsing ? 0 : 1)
            .animation(
                Animation.easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: false),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
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
    
    private var waitingSession: IslandState.Session? {
        state.sessions.first { $0.status == .waiting }
    }
    
    private var collapsedPill: some View {
        HStack(spacing: 0) {
            Image(systemName: "apple.terminal.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(accentColor)
                .frame(width: 50, height: collapsedHeight)
            
            Spacer()
            
            if let waiting = waitingSession {
                Image(systemName: permissionIcon(for: waiting.permissionType))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yellow)
                    .frame(width: 50, height: collapsedHeight)
            } else {
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(accentColor)
                    .frame(width: 50, height: collapsedHeight)
            }
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
            
            Text("Start an OpenCode session\nto monitor activity here")
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
        let isWaiting = session.status == .waiting
        
        return HStack(spacing: 12) {
            // Pulsing indicator for waiting state
            ZStack {
                if isWaiting {
                    Circle()
                        .fill(Color.yellow.opacity(0.3))
                        .frame(width: 16, height: 16)
                        .modifier(PulseAnimation())
                }
                Circle()
                    .fill(statusColor(for: session.status))
                    .frame(width: 8, height: 8)
            }
            .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                
                if isWaiting {
                    // Prominent waiting message with contextual icon
                    HStack(spacing: 6) {
                        Image(systemName: permissionIcon(for: session.permissionType))
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        
                        Text(permissionLabel(for: session.permissionType))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.yellow)
                        
                        if let tool = session.pendingTool, tool != session.permissionType {
                            Text("(\(tool))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.yellow.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                } else {
                    Text(session.status.rawValue)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(session.status == .processing ? accentColor : .white.opacity(0.4))
                }
            }
            
            Spacer()
            
            if isWaiting {
                Image(systemName: permissionIcon(for: session.permissionType))
                    .font(.system(size: 16))
                    .foregroundColor(.yellow.opacity(0.8))
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isWaiting ? Color.yellow.opacity(0.1) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isWaiting ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
    
    private func statusColor(for status: IslandState.Session.Status) -> Color {
        switch status {
        case .idle: return .white.opacity(0.3)
        case .processing: return accentColor
        case .waiting: return .yellow
        }
    }
    
    private func permissionIcon(for permissionType: String?) -> String {
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
    
    private func permissionLabel(for permissionType: String?) -> String {
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
    
    private var footerBar: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("Approve actions in terminal")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
            
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
