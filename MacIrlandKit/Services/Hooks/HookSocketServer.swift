import Foundation
import os.log

private let hookLogger = os.Logger(subsystem: "com.macirland.hooksocket", category: "HookSocketServer")

private func debugWrite(_ msg: String) {
    // Debug logging to file - only active in debug builds
    #if DEBUG
    let logPath = "/tmp/macirland-socket-debug.log"
    if FileManager.default.fileExists(atPath: logPath) {
        if let file = FileHandle(forWritingAtPath: logPath) {
            file.seekToEndOfFile()
            if let data = ("\(msg)\n").data(using: .utf8) {
                file.write(data)
            }
            file.closeFile()
        }
    } else {
        if let data = ("\(msg)\n").data(using: .utf8) {
            FileManager.default.createFile(atPath: logPath, contents: data, attributes: nil)
        }
    }
    #endif
}

/// Unix socket server that receives events from Claude Code Python hooks.
/// Uses Foundation's FileHandle for cross-process IPC on macOS.
///
/// Architecture:
/// - Server listens on a Unix socket path
/// - Each Python hook instance connects as a client
/// - Events arrive as JSON on the socket connection
/// - PermissionRequest events require a response sent back on the same socket
public final class HookSocketServer: @unchecked Sendable {
    public typealias EventHandler = @MainActor (HookEvent) -> Void
    public typealias ConnectionHandler = @MainActor (Bool) -> Void
    public typealias DisconnectionHandler = @MainActor (String) -> Void

    /// Default socket path within user's Application Support directory.
    public static func defaultSocketPath() -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MacIrland/hook.sock").path
    }

    private var listenerHandle: FileHandle?
    private let socketPath: String
    private var activeHandles: [FileHandle] = []
    /// Per-connection receive buffers for handling messages split across reads.
    /// ObjectIdentifier(FileHandle) -> accumulated Data.
    private var receiveBuffers: [ObjectIdentifier: Data] = [:]
    private let queue = DispatchQueue(label: "com.macirland.hooksocket", qos: .userInitiated)
    private let lock = NSLock()
    private var isRunning = false
    private var pollTimer: DispatchSourceTimer?

    /// Tracks pending permission requests: sessionID -> (connection, expiration)
    private var pendingPermissions: [String: (FileHandle, Date)] = [:]

    private var eventHandler: EventHandler?
    private var connectionHandler: ((Bool) -> Void)?
    private var disconnectionHandler: DisconnectionHandler?

    public let permissionTimeoutSeconds: TimeInterval = 300

    public init(socketPath: String? = nil) {
        self.socketPath = socketPath ?? Self.defaultSocketPath()
    }

    /// Starts listening on the Unix socket.
    /// Removes any stale socket file before binding.
    public func start(
        eventHandler: @escaping EventHandler,
        connectionHandler: ((Bool) -> Void)? = nil,
        disconnectionHandler: DisconnectionHandler? = nil
    ) throws {
        self.eventHandler = eventHandler
        self.connectionHandler = connectionHandler
        self.disconnectionHandler = disconnectionHandler

        // Clean up stale socket
        try? FileManager.default.removeItem(atPath: socketPath)

        // Ensure directory exists
        let socketDir = (socketPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: socketDir, withIntermediateDirectories: true)

        // Create Unix socket
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw HookSocketError.failedToCreateListener
        }

        // Bind to socket path
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                let pathBufferPtr = UnsafeMutableRawPointer(pathPtr).assumingMemoryBound(to: CChar.self)
                strcpy(pathBufferPtr, ptr)
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(fd, sockaddrPtr, addrLen)
            }
        }

        guard bindResult == 0 else {
            close(fd)
            throw HookSocketError.failedToCreateListener
        }

        // Listen for connections
        guard listen(fd, 5) == 0 else {
            close(fd)
            throw HookSocketError.failedToCreateListener
        }

        // Set non-blocking mode on listener so accept doesn't block
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        // Wrap in FileHandle for convenience
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        self.listenerHandle = handle
        self.isRunning = true

        // Start polling timer for accept + permission timeouts
        startPolling()
    }

    /// Stops the server and closes all connections.
    public func stop() {
        isRunning = false
        acceptSource?.cancel()
        acceptSource = nil
        pollTimer?.cancel()
        pollTimer = nil

        listenerHandle?.closeFile()
        listenerHandle = nil

        lock.lock()
        for handle in activeHandles {
            handle.closeFile()
        }
        activeHandles.removeAll()
        lock.unlock()

        try? FileManager.default.removeItem(atPath: socketPath)
    }

    /// Sends a permission response for a pending session.
    public func sendPermissionResponse(sessionID: String, response: HookResponse) {
        lock.lock()
        guard let (handle, _) = pendingPermissions.removeValue(forKey: sessionID) else {
            lock.unlock()
            return
        }
        lock.unlock()

        do {
            let data = try JSONEncoder().encode(response)
            let framedData = framing(data)
            try? handle.write(contentsOf: framedData)
            handle.closeFile()
        } catch {
            // Log error - response failed
        }
    }

    // MARK: - Private

    private var acceptSource: DispatchSourceRead?
    private var clientSources: [ObjectIdentifier: DispatchSourceRead] = [:]

    private func startPolling() {
        // Use DispatchSource to monitor the listener socket for incoming connections
        guard let handle = listenerHandle else { return }
        let fd = handle.fileDescriptor

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptConnections()
        }
        source.resume()
        self.acceptSource = source

        // Also start a timer for permission timeouts
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            self?.checkPermissionTimeouts()
        }
        timer.resume()
        self.pollTimer = timer
    }

    private func acceptConnections() {
        guard let handle = listenerHandle, isRunning else { return }

        let fd = handle.fileDescriptor

        // Non-blocking accept
        let clientFD = accept(fd, nil, nil)
        guard clientFD >= 0 else { return }

        // Set client socket to non-blocking mode
        let flags = fcntl(clientFD, F_GETFL, 0)
        _ = fcntl(clientFD, F_SETFL, flags | O_NONBLOCK)

        let clientHandle = FileHandle(fileDescriptor: clientFD, closeOnDealloc: false)
        fputs("HOOK_DEBUG: accepted client fd=\(clientFD)\n", stderr)
        fflush(stderr)

        // Set up a dispatch source to monitor the client socket for data
        let clientSource = DispatchSource.makeReadSource(fileDescriptor: clientFD, queue: queue)
        clientSource.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.handleClientData(clientFD, handle: clientHandle)
        }
        clientSource.setCancelHandler { [weak self] in
            guard let self = self else { return }
            self.cleanupClient(handle: clientHandle, source: clientSource)
        }
        clientSource.resume()

        let handleID = ObjectIdentifier(clientHandle)
        lock.lock()
        clientSources[handleID] = clientSource
        activeHandles.append(clientHandle)
        lock.unlock()

        hookLogger.info("new client handle created with dispatch source")

        let handler = connectionHandler
        DispatchQueue.main.async {
            handler?(true)
        }
    }

    private func handleClientData(_ fd: Int32, handle: FileHandle) {
        let handleID = ObjectIdentifier(handle)

        // Check if this source is still registered
        lock.lock()
        let isRegistered = clientSources[handleID] != nil
        lock.unlock()

        if !isRegistered {
            return
        }

        // Use recv directly on raw fd to avoid FileHandle issues
        var recvBuffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = recv(fd, &recvBuffer, recvBuffer.count, 0)

        if bytesRead <= 0 {
            cancelClientSource(for: handle)
            return
        }

        let incoming = Data(bytes: recvBuffer, count: bytesRead)

        // Append to per-connection buffer
        lock.lock()
        let existingBuffer = receiveBuffers[handleID] ?? Data()
        receiveBuffers[handleID] = existingBuffer + incoming
        lock.unlock()

        // Process buffered data
        let messages = parseMessages(handleID: handleID)
        let bufferSize = self.receiveBuffers[handleID]?.count ?? 0
        hookLogger.info("parsed \(messages.count) messages from buffer size \(bufferSize)")

        let decoder = JSONDecoder()
        for message in messages {
            do {
                let event = try decoder.decode(HookEvent.self, from: message)
                hookLogger.info("decoded event=\(String(describing: event.event)) sessionID=\(event.sessionID) tty=\(event.tty)")
                if event.event == .permissionRequest {
                    lock.lock()
                    let expiration = Date().addingTimeInterval(permissionTimeoutSeconds)
                    pendingPermissions[event.sessionID] = (handle, expiration)
                    lock.unlock()
                }
                let handler = self.eventHandler
                DispatchQueue.main.async {
                    handler?(event)
                }
            } catch {
                hookLogger.error("decode error: \(error.localizedDescription)")
            }
        }
    }

    private func cancelClientSource(for handle: FileHandle) {
        let handleID = ObjectIdentifier(handle)
        lock.lock()
        if let source = clientSources.removeValue(forKey: handleID) {
            source.cancel()
        }
        activeHandles.removeAll { $0 === handle }
        receiveBuffers.removeValue(forKey: handleID)
        lock.unlock()
        handle.closeFile()
        let handler = disconnectionHandler
        DispatchQueue.main.async {
            handler?("client disconnected")
        }
    }

    private func cleanupClient(handle: FileHandle, source: DispatchSourceRead) {
        // Called when source is cancelled
        lock.lock()
        clientSources.removeValue(forKey: ObjectIdentifier(handle))
        activeHandles.removeAll { $0 === handle }
        receiveBuffers.removeValue(forKey: ObjectIdentifier(handle))
        lock.unlock()
        handle.closeFile()
    }

    private func readFromConnections() {
        // Legacy method - no longer used, replaced by readabilityHandler-based approach
        // Kept for compatibility but not called
        lock.lock()
        let handles = activeHandles
        lock.unlock()

        for _ in handles {
            // Empty - dispatch source handles reads
        }
    }

    private func readFromConnectionsOLD() {
        lock.lock()
        let handles = activeHandles
        lock.unlock()

        var closedHandles: [FileHandle] = []

        // Shared JSON decoder - using explicit CodingKeys in HookEvent
        let decoder = JSONDecoder()

        for handle in handles {
            let data: Data?
            do {
                data = try handle.read(upToCount: 65536)
            } catch {
                // Read error — client likely crashed, mark for cleanup
                closedHandles.append(handle)
                notifyDisconnection(reason: "read error: \(error.localizedDescription)")
                continue
            }

            guard let incoming = data, !incoming.isEmpty else {
                // EOF — client disconnected gracefully
                closedHandles.append(handle)
                notifyDisconnection(reason: "client disconnected")
                continue
            }

            // Append to per-connection buffer
            let handleID = ObjectIdentifier(handle)
            lock.lock()
            let buffer = receiveBuffers[handleID] ?? Data()
            receiveBuffers[handleID] = buffer + incoming
            lock.unlock()

            // Process buffered data
            let messages = parseMessages(handleID: handleID)
            self.receiveBuffers[handleID] = Data()
            lock.unlock()

            for message in messages {
                do {
                    debugWrite("readFromConnections: about to decode")
                    let event = try decoder.decode(HookEvent.self, from: message)
                    debugWrite("readFromConnections: decode succeeded")
                    debugWrite("readFromConnections: decoded event=\(String(describing: event.event))")
                    hookLogger.info("decoded event=\(String(describing: event.event)) sessionID=\(event.sessionID) tty=\(event.tty)")
                    if event.event == .permissionRequest {
                        lock.lock()
                        let expiration = Date().addingTimeInterval(permissionTimeoutSeconds)
                        pendingPermissions[event.sessionID] = (handle, expiration)
                        lock.unlock()
                    }
                    let handler = self.eventHandler
                    debugWrite("readFromConnections: calling event handler")
                    DispatchQueue.main.async {
                        debugWrite("readFromConnections: event handler running")
                        handler?(event)
                    }
                    debugWrite("readFromConnections: dispatched to main")
                } catch {
                    debugWrite("readFromConnections: decode error: \(error.localizedDescription)")
                    hookLogger.error("decode error: \(error.localizedDescription)")
                }
            }
        }

        // Clean up closed connections
        if !closedHandles.isEmpty {
            lock.lock()
            for handle in closedHandles {
                let handleID = ObjectIdentifier(handle)
                receiveBuffers.removeValue(forKey: handleID)
                activeHandles.removeAll { $0 === handle }
                handle.closeFile()
            }
            lock.unlock()
        }
    }

    private func notifyDisconnection(reason: String) {
        let handler = disconnectionHandler
        DispatchQueue.main.async {
            handler?(reason)
        }
    }

    private func checkPermissionTimeouts() {
        let now = Date()
        lock.lock()
        var expired = [String]()
        for (sessionID, (_, expiration)) in pendingPermissions {
            if now >= expiration {
                expired.append(sessionID)
            }
        }
        lock.unlock()

        for sessionID in expired {
            // Auto-deny on timeout
            sendPermissionResponse(sessionID: sessionID, response: HookResponse(decision: .deny))
        }
    }

    // MARK: - Framing

    /// Unix socket messages are framed with a 4-byte length prefix (big-endian).
    private func framing(_ data: Data) -> Data {
        var framed = Data()
        var length = UInt32(data.count).bigEndian
        framed.append(Data(bytes: &length, count: 4))
        framed.append(data)
        return framed
    }

    /// Parses messages from the buffered data for a connection.
    /// Returns complete messages and keeps incomplete data in the buffer.
    private func parseMessages(handleID: ObjectIdentifier) -> [Data] {
        var messages: [Data] = []

        lock.lock()
        guard let buffer = receiveBuffers[handleID] else {
            lock.unlock()
            return []
        }
        lock.unlock()

        var offset = 0

        while offset + 4 <= buffer.count {
            // Read 4-byte length prefix
            let lengthData = buffer.subdata(in: offset..<(offset + 4))
            let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            offset += 4

            // Check if we have the full message
            if offset + Int(length) <= buffer.count {
                let message = buffer.subdata(in: offset..<(offset + Int(length)))
                messages.append(message)
                offset += Int(length)
            } else {
                // Incomplete message — break and wait for more data
                break
            }
        }

        // Keep remaining (incomplete) data in buffer
        if offset > 0 && offset < buffer.count {
            let remaining = buffer.subdata(in: offset..<buffer.count)
            lock.lock()
            receiveBuffers[handleID] = remaining
            lock.unlock()
        } else if offset >= buffer.count {
            lock.lock()
            receiveBuffers[handleID] = Data()
            lock.unlock()
        }

        return messages
    }
}

public enum HookSocketError: Error, LocalizedError {
    case failedToCreateListener
    case connectionFailed
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .failedToCreateListener:
            return "Failed to create Unix socket listener"
        case .connectionFailed:
            return "Connection to hook socket failed"
        case .encodingFailed:
            return "Failed to encode hook response"
        }
    }
}
