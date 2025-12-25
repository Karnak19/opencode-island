import AppKit
import Combine

/// Monitors global and local mouse events
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

/// Singleton for accessing mouse event streams
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
