import Foundation
import os.log

private let logger = Logger(subsystem: "com.opencodeisland", category: "Socket")

// MARK: - Event Types

/// Event received from OpenCode plugin
struct PluginEvent: Codable {
    let version: String
    let type: EventType
    let timestamp: Int64
    let sessionId: String
    let payload: EventPayload
    
    enum CodingKeys: String, CodingKey {
        case version, type, timestamp
        case sessionId = "session_id"
        case payload
    }
}

enum EventType: String, Codable {
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case sessionUpdate = "session_update"
    case toolExecuted = "tool_executed"
    case event = "event"
}

struct EventPayload: Codable {
    // Session info
    let cwd: String?
    let title: String?
    let model: String?
    
    // Tool info
    let tool: String?
    let toolInput: [String: AnyCodable]?
    let toolUseId: String?
    
    // Status
    let status: String?
    let message: String?
    
    // Permission info
    let permissionType: String?
    
    enum CodingKeys: String, CodingKey {
        case cwd, title, model, tool, status, message
        case toolInput = "tool_input"
        case toolUseId = "tool_use_id"
        case permissionType = "permission_type"
    }
}

// MARK: - Socket Server

class SocketServer {
    static let shared = SocketServer()
    static let socketPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".opencode-island/socket").path
    
    private var serverSocket: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private let queue = DispatchQueue(label: "com.opencodeisland.socket", qos: .userInitiated)
    
    var onEvent: ((PluginEvent) -> Void)?
    
    private init() {}
    
    // MARK: - Server Lifecycle
    
    func start() {
        queue.async { [weak self] in
            self?.startServer()
        }
    }
    
    func stop() {
        acceptSource?.cancel()
        acceptSource = nil
        
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
        
        unlink(Self.socketPath)
        
        logger.info("Socket server stopped")
    }
    
    private func startServer() {
        // Create directory if needed
        let socketDir = (Self.socketPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: socketDir, withIntermediateDirectories: true)
        
        // Remove existing socket
        unlink(Self.socketPath)
        
        // Create socket
        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            logger.error("Failed to create socket: \(errno)")
            return
        }
        
        // Set non-blocking
        let flags = fcntl(serverSocket, F_GETFL)
        _ = fcntl(serverSocket, F_SETFL, flags | O_NONBLOCK)
        
        // Bind to path
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        Self.socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                let pathBufferPtr = UnsafeMutableRawPointer(pathPtr)
                    .assumingMemoryBound(to: CChar.self)
                strcpy(pathBufferPtr, ptr)
            }
        }
        
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(serverSocket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        
        guard bindResult == 0 else {
            logger.error("Failed to bind socket: \(errno)")
            close(serverSocket)
            serverSocket = -1
            return
        }
        
        // Set permissions (readable/writable by user)
        chmod(Self.socketPath, 0o600)
        
        // Listen
        guard listen(serverSocket, 10) == 0 else {
            logger.error("Failed to listen: \(errno)")
            close(serverSocket)
            serverSocket = -1
            return
        }
        
        logger.info("Socket server listening on \(Self.socketPath, privacy: .public)")
        
        // Set up accept handler
        acceptSource = DispatchSource.makeReadSource(fileDescriptor: serverSocket, queue: queue)
        acceptSource?.setEventHandler { [weak self] in
            self?.acceptConnection()
        }
        acceptSource?.setCancelHandler { [weak self] in
            if let fd = self?.serverSocket, fd >= 0 {
                close(fd)
                self?.serverSocket = -1
            }
        }
        acceptSource?.resume()
    }
    
    // MARK: - Connection Handling
    
    private func acceptConnection() {
        let clientSocket = accept(serverSocket, nil, nil)
        guard clientSocket >= 0 else { return }
        
        // Prevent SIGPIPE
        var nosigpipe: Int32 = 1
        setsockopt(clientSocket, SOL_SOCKET, SO_NOSIGPIPE, &nosigpipe, socklen_t(MemoryLayout<Int32>.size))
        
        handleClient(clientSocket)
    }
    
    private func handleClient(_ clientSocket: Int32) {
        // Set non-blocking
        let flags = fcntl(clientSocket, F_GETFL)
        _ = fcntl(clientSocket, F_SETFL, flags | O_NONBLOCK)
        
        // Read data with polling
        var allData = Data()
        var buffer = [UInt8](repeating: 0, count: 65536)
        var pollFd = pollfd(fd: clientSocket, events: Int16(POLLIN), revents: 0)
        
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < 0.5 {
            let pollResult = poll(&pollFd, 1, 50)
            
            if pollResult > 0 && (pollFd.revents & Int16(POLLIN)) != 0 {
                let bytesRead = read(clientSocket, &buffer, buffer.count)
                
                if bytesRead > 0 {
                    allData.append(contentsOf: buffer[0..<bytesRead])
                } else if bytesRead == 0 {
                    break  // Connection closed
                } else if errno != EAGAIN && errno != EWOULDBLOCK {
                    break  // Error
                }
            } else if pollResult == 0 && !allData.isEmpty {
                break  // Timeout with data
            } else if pollResult < 0 {
                break  // Error
            }
        }
        
        guard !allData.isEmpty else {
            close(clientSocket)
            return
        }
        
        // Parse event
        guard let event = try? JSONDecoder().decode(PluginEvent.self, from: allData) else {
            logger.warning("Failed to parse event: \(String(data: allData, encoding: .utf8) ?? "?")")
            close(clientSocket)
            return
        }
        
        logger.info("Received event: \(event.type.rawValue) for session \(event.sessionId.prefix(8))")
        
        close(clientSocket)
        
        // Notify handler on main thread
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(event)
        }
    }
}

// MARK: - AnyCodable

/// Type-erasing Codable wrapper for heterogeneous JSON values
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Cannot encode value"))
        }
    }
}
