import Foundation
import Network

/// 客户端侧 socket 连接（MpetApp / mpet-cc-watcher 共用）
public actor SoulClient {
    private let socketPath: String
    private var connection: NWConnection?
    private var codec = LineCodec()
    private var handler: (@Sendable (PeripheralMessage) -> Void)?
    private var isConnected = false
    private var pendingSends: [PeripheralMessage] = []
    private var reconnectTask: Task<Void, Never>?
    private let reconnectDelay: UInt64

    public var pendingSendCount: Int { pendingSends.count }

    public init(socketPath: String, reconnectDelay: UInt64 = 2_000_000_000) {
        self.socketPath = socketPath; self.reconnectDelay = reconnectDelay
    }
    public func setMessageHandler(_ handler: @escaping @Sendable (PeripheralMessage) -> Void) { self.handler = handler }

    public func connect() {
        reconnectTask?.cancel()
        doConnect()
    }
    public func disconnect() {
        reconnectTask?.cancel(); connection?.cancel(); connection = nil; isConnected = false
    }
    private func doConnect() {
        let conn = NWConnection(to: .unix(path: socketPath), using: .tcp)
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task { await self.handleStateChange(state) }
        }
        conn.start(queue: .global()); connection = conn
    }
    private func handleStateChange(_ state: NWConnection.State) {
        switch state {
        case .ready: isConnected = true; flushPendingSends(); startReceiving()
        case .failed, .cancelled: isConnected = false; scheduleReconnect()
        default: break
        }
    }
    private func scheduleReconnect() {
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.reconnectDelay)
            guard !Task.isCancelled else { return }
            await self.doConnect()
        }
    }
    public func send(_ message: PeripheralMessage) {
        guard isConnected, let conn = connection, let data = try? LineCodec.encode(message) else {
            pendingSends.append(message); return
        }
        conn.send(content: data, completion: .contentProcessed { _ in })
    }
    private func flushPendingSends() {
        guard let conn = connection else { return }
        for msg in pendingSends {
            guard let data = try? LineCodec.encode(msg) else { continue }
            conn.send(content: data, completion: .contentProcessed { _ in })
        }
        pendingSends.removeAll()
    }
    private func startReceiving() {
        guard let conn = connection else { return }
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, done, err in
            guard let self else { return }
            Task {
                if let data, !data.isEmpty {
                    let msgs = (try? await self.feedCodec(data)) ?? []
                    for m in msgs { await self.handleReceived(m) }
                }
                if !done && err == nil { await self.startReceiving() }
            }
        }
    }
    private func feedCodec(_ data: Data) throws -> [PeripheralMessage] { try codec.feed(data) }
    public func handleReceived(_ message: PeripheralMessage) { handler?(message) }
    public func makeHello() -> PeripheralMessage { .hello(role: "body", name: "MpetApp", proto: 1) }
    public func performHandshake() { send(makeHello()) }
}
