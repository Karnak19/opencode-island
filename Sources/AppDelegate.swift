import AppKit
import Combine
import os.log
import SwiftUI

private let logger = Logger(subsystem: "com.opencodeisland", category: "AppDelegate")

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var islandWindow: NotchPanel?
    private var setupWindow: NSWindow?
    private var islandState = IslandState()
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarIcon()
        setupIslandWindow()
        setupEventMonitors()
        setupSocketServer()
        installPluginIfNeeded()
    }
    
    // MARK: - Plugin Installation
    
    private func installPluginIfNeeded() {
        logger.info("Checking plugin installation...")
        
        let status = PluginInstaller.installPlugin()
        
        // Update the island state with plugin status
        DispatchQueue.main.async { [weak self] in
            self?.updatePluginStatus(from: status)
            
            // Show setup alert if there was an issue
            if !status.isSuccess {
                self?.showSetupAlert()
            }
        }
    }
    
    private func updatePluginStatus(from status: PluginInstaller.InstallationStatus) {
        switch status.result {
        case .success:
            logger.info("Plugin installed successfully")
            islandState.pluginStatus = .installed
        case .alreadyInstalled:
            logger.info("Plugin already installed")
            islandState.pluginStatus = .installed
        case .opencodeNotInstalled:
            logger.warning("OpenCode not installed")
            islandState.pluginStatus = .opencodeNotFound
        case .copyFailed(let error):
            logger.error("Plugin installation failed: \(error.localizedDescription)")
            islandState.pluginStatus = .installFailed(error.localizedDescription)
        case .pluginResourceMissing:
            logger.error("Plugin resource missing from bundle")
            islandState.pluginStatus = .installFailed("Plugin resource missing from app bundle")
        }
    }
    
    private func showSetupAlert() {
        islandState.showSetupAlert = true
        
        let alertView = SetupAlertView(state: islandState)
        let hostingView = NSHostingView(rootView: alertView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Opencode Island Setup"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        
        setupWindow = window
        
        // Close window when showSetupAlert becomes false
        islandState.$showSetupAlert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                if !show {
                    self?.setupWindow?.close()
                    self?.setupWindow = nil
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Socket Server
    
    private func setupSocketServer() {
        SocketServer.shared.onEvent = { [weak self] event in
            self?.handlePluginEvent(event)
        }
        SocketServer.shared.start()
    }
    
    private func handlePluginEvent(_ event: PluginEvent) {
        logger.debug("Received event: \(event.type.rawValue) for session \(event.sessionId)")
        logger.debug("Current sessions: \(self.islandState.sessions.map { "\($0.id.prefix(8)):\($0.title)" })")
        
        switch event.type {
        case .sessionStart:
            handleSessionStart(event)
        case .sessionEnd:
            islandState.sessions.removeAll { $0.id == event.sessionId }
        case .sessionUpdate:
            handleSessionUpdate(event)
        case .toolExecuted:
            handleToolExecuted(event)
        case .event:
            handleGenericEvent(event)
        }
        
        updateIslandVisibility()
    }
    
    private func handleSessionStart(_ event: PluginEvent) {
        if let index = islandState.sessions.firstIndex(where: { $0.id == event.sessionId }) {
            logger.debug("Updating existing session at index \(index)")
            islandState.sessions[index].status = .idle
            if let title = event.payload.title {
                islandState.sessions[index].title = title
            }
        } else {
            logger.debug("Adding new session with id \(event.sessionId)")
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
    }
    
    private func handleSessionUpdate(_ event: PluginEvent) {
        guard let index = islandState.sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
        
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
    
    private func handleToolExecuted(_ event: PluginEvent) {
        guard let index = islandState.sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
        islandState.sessions[index].status = .processing
        islandState.sessions[index].pendingTool = nil
        islandState.sessions[index].pendingToolId = nil
        islandState.sessions[index].permissionType = nil
    }
    
    private func handleGenericEvent(_ event: PluginEvent) {
        guard let index = islandState.sessions.firstIndex(where: { $0.id == event.sessionId }),
              let status = event.payload.status else { return }
        
        switch status {
        case "processing":
            islandState.sessions[index].status = .processing
        case "idle":
            islandState.sessions[index].status = .idle
        default:
            break
        }
    }
    
    private func updateIslandVisibility() {
        let hasActiveWork = islandState.sessions.contains { $0.status != .idle }
        islandState.showPending = hasActiveWork
        
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
        guard !islandState.sessions.isEmpty else { return }
        withAnimation(Theme.Animation.spring) {
            islandState.isExpanded.toggle()
        }
    }
    
    // MARK: - Island Window
    
    private func setupIslandWindow() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let windowSize = Theme.Dimensions.windowSize
        
        let windowRect = NSRect(
            x: screenFrame.midX - (windowSize.width / 2),
            y: screenFrame.maxY - windowSize.height,
            width: windowSize.width,
            height: windowSize.height
        )
        
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
        
        islandState.$isExpanded
            .receive(on: DispatchQueue.main)
            .sink { [weak panel] isExpanded in
                panel?.ignoresMouseEvents = !isExpanded
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Event Monitors
    
    private func setupEventMonitors() {
        EventMonitors.shared.mouseLocation
            .receive(on: DispatchQueue.main)
            .sink { _ in }
            .store(in: &cancellables)
        
        EventMonitors.shared.mouseDown
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleMouseDown(event)
            }
            .store(in: &cancellables)
    }
    
    private func handleMouseDown(_ event: NSEvent) {
        let point = NSEvent.mouseLocation
        
        if islandState.isExpanded {
            if isPointInNotchArea(point) || !isPointInIsland(point) {
                withAnimation(Theme.Animation.spring) {
                    islandState.isExpanded = false
                }
            }
        } else {
            if isPointInNotchArea(point) && !islandState.sessions.isEmpty {
                withAnimation(Theme.Animation.spring) {
                    islandState.isExpanded = true
                }
            }
        }
    }
    
    private func isPointInNotchArea(_ point: CGPoint) -> Bool {
        guard let screen = NSScreen.main else { return false }
        
        let screenFrame = screen.frame
        let notchSize = Theme.Dimensions.notchSize
        
        let notchRect = CGRect(
            x: screenFrame.midX - notchSize.width / 2,
            y: screenFrame.maxY - notchSize.height,
            width: notchSize.width,
            height: notchSize.height
        )
        
        return notchRect.contains(point)
    }
    
    private func isPointInIsland(_ point: CGPoint) -> Bool {
        guard let screen = NSScreen.main else { return false }
        
        let screenFrame = screen.frame
        let width: CGFloat
        let height: CGFloat
        
        if islandState.isExpanded {
            let size = Theme.Dimensions.expandedSize
            width = size.width
            height = size.height
        } else if islandState.showPending {
            let size = Theme.Dimensions.collapsedSize
            width = size.width
            height = size.height
        } else {
            return false
        }
        
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
