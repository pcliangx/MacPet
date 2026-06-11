// Sources/SoulCore/Protocol/LineCodec.swift
import Foundation

/// NDJSON：一行一个 JSON 消息。带缓冲的流式拆帧。
public struct LineCodec {
    private var buffer = Data()
    public init() {}

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    public static func encode(_ m: PeripheralMessage) throws -> Data {
        var d = try encoder.encode(m); d.append(UInt8(ascii: "\n")); return d
    }
    public static func decodeLine(_ data: Data) throws -> PeripheralMessage {
        try decoder.decode(PeripheralMessage.self, from: data)
    }
    /// 喂入任意分片，返回完整消息列表
    public mutating func feed(_ chunk: Data) throws -> [PeripheralMessage] {
        buffer.append(chunk)
        var out: [PeripheralMessage] = []
        while let nl = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer.subdata(in: buffer.startIndex..<nl)
            buffer.removeSubrange(buffer.startIndex...nl)
            if !line.isEmpty { out.append(try Self.decodeLine(line)) }
        }
        return out
    }
}
