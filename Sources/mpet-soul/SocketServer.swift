import Foundation
import Network
import SoulCore

/// Unix socket NDJSON 服务。安全基线：socket 放 0700 目录（文件系统隔离同机其他用户）；
/// 对端 uid 校验列入 M1 加固（spec §15）。
final class SocketServer: @unchecked Sendable {
    typealias Handler = @Sendable (PeripheralMessage, @escaping @Sendable (PeripheralMessage) -> Void) -> Void
    private let listener: NWListener
    private var connections: [ObjectIdentifier: (NWConnection, LineCodec)] = [:]
    private let lock = NSLock()
    private let handler: Handler

    init(socketPath: String, handler: @escaping Handler) throws {
        self.handler = handler
        try? FileManager.default.removeItem(atPath: socketPath)
        let params = NWParameters()
        params.defaultProtocolStack.transportProtocol = NWProtocolTCP.Options()
        params.requiredLocalEndpoint = NWEndpoint.unix(path: socketPath)
        params.allowLocalEndpointReuse = true
        listener = try NWListener(using: params)
    }

    func start() {
        listener.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
        listener.start(queue: .global())
    }

    private func accept(_ conn: NWConnection) {
        lock.lock(); connections[ObjectIdentifier(conn)] = (conn, LineCodec()); lock.unlock()
        conn.start(queue: .global())
        receive(conn)
    }

    private func receive(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, done, err in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.lock.lock()
                var codec = self.connections[ObjectIdentifier(conn)]?.1 ?? LineCodec()
                let msgs = (try? codec.feed(data)) ?? []
                self.connections[ObjectIdentifier(conn)]?.1 = codec
                self.lock.unlock()
                let send: @Sendable (PeripheralMessage) -> Void = { [weak conn] m in
                    guard let conn, let d = try? LineCodec.encode(m) else { return }
                    conn.send(content: d, completion: .contentProcessed { _ in })
                }
                for m in msgs { self.handler(m, send) }
            }
            if done || err != nil {
                self.lock.lock(); self.connections.removeValue(forKey: ObjectIdentifier(conn)); self.lock.unlock()
                conn.cancel()
            } else {
                self.receive(conn)
            }
        }
    }

    func broadcast(_ m: PeripheralMessage) {
        guard let d = try? LineCodec.encode(m) else { return }
        lock.lock(); let conns = connections.values.map(\.0); lock.unlock()
        for c in conns { c.send(content: d, completion: .contentProcessed { _ in }) }
    }
}
