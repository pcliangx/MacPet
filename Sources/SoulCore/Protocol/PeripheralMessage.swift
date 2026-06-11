// Sources/SoulCore/Protocol/PeripheralMessage.swift
import Foundation

public struct PerceptAction: Codable, Equatable, Sendable {
    public let id: String, label: String
    public init(id: String, label: String) { self.id = id; self.label = label }
}

public enum PerceptPriority: String, Codable, Sendable { case ambient, nudge, alert }

public struct Percept: Codable, Equatable, Sendable {
    public let id: String
    public let kind: String
    public let priority: PerceptPriority
    public let payload: [String: JSONValue]
    public let actions: [PerceptAction]
    public let at: Date
    public init(id: String = UUID().uuidString, kind: String, priority: PerceptPriority,
                payload: [String: JSONValue] = [:], actions: [PerceptAction] = [], at: Date) {
        self.id = id; self.kind = kind; self.priority = priority
        self.payload = payload; self.actions = actions; self.at = at
    }
}

/// 外设协议族 v0（spec §10.3）。t 字段路由；未知类型容忍为 .unknown。
public enum PeripheralMessage: Equatable, Sendable {
    case hello(role: String, name: String, proto: Int)
    case helloOK(proto: Int, soulVersion: String)
    case event(kind: String, payload: [String: JSONValue])
    case senseEvent(Percept)
    case chatUser(text: String)
    case chatDelta(text: String)
    case chatDone
    case directive(kind: String, payload: [String: JSONValue])
    case toolCall(id: String, name: String, args: [String: JSONValue])
    case toolResult(id: String, ok: Bool, content: JSONValue)
    case fuelReport(date: String, raw: Double)
    case actionInvoke(eventId: String, actionId: String)
    case status
    case statusOK([String: JSONValue])
    case ping, pong, bye
    case unknown(t: String)
}

extension PeripheralMessage: Codable {
    private enum K: String, CodingKey {
        case t, role, name, proto, soulVersion, kind, payload, percept, text,
             id, args, ok, content, date, raw, eventId, actionId, fields
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        let t = try c.decode(String.self, forKey: .t)
        switch t {
        case "hello": self = .hello(role: try c.decode(String.self, forKey: .role),
                                    name: try c.decode(String.self, forKey: .name),
                                    proto: try c.decode(Int.self, forKey: .proto))
        case "hello.ok": self = .helloOK(proto: try c.decode(Int.self, forKey: .proto),
                                         soulVersion: try c.decode(String.self, forKey: .soulVersion))
        case "event": self = .event(kind: try c.decode(String.self, forKey: .kind),
                                    payload: try c.decodeIfPresent([String: JSONValue].self, forKey: .payload) ?? [:])
        case "sense.event": self = .senseEvent(try c.decode(Percept.self, forKey: .percept))
        case "chat.user": self = .chatUser(text: try c.decode(String.self, forKey: .text))
        case "chat.delta": self = .chatDelta(text: try c.decode(String.self, forKey: .text))
        case "chat.done": self = .chatDone
        case "directive": self = .directive(kind: try c.decode(String.self, forKey: .kind),
                                            payload: try c.decodeIfPresent([String: JSONValue].self, forKey: .payload) ?? [:])
        case "tool.call": self = .toolCall(id: try c.decode(String.self, forKey: .id),
                                           name: try c.decode(String.self, forKey: .name),
                                           args: try c.decodeIfPresent([String: JSONValue].self, forKey: .args) ?? [:])
        case "tool.result": self = .toolResult(id: try c.decode(String.self, forKey: .id),
                                               ok: try c.decode(Bool.self, forKey: .ok),
                                               content: try c.decodeIfPresent(JSONValue.self, forKey: .content) ?? .null)
        case "fuel.report": self = .fuelReport(date: try c.decode(String.self, forKey: .date),
                                               raw: try c.decode(Double.self, forKey: .raw))
        case "action.invoke": self = .actionInvoke(eventId: try c.decode(String.self, forKey: .eventId),
                                                   actionId: try c.decode(String.self, forKey: .actionId))
        case "status": self = .status
        case "status.ok": self = .statusOK(try c.decodeIfPresent([String: JSONValue].self, forKey: .fields) ?? [:])
        case "ping": self = .ping
        case "pong": self = .pong
        case "bye": self = .bye
        default: self = .unknown(t: t)
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        switch self {
        case .hello(let role, let name, let proto):
            try c.encode("hello", forKey: .t); try c.encode(role, forKey: .role)
            try c.encode(name, forKey: .name); try c.encode(proto, forKey: .proto)
        case .helloOK(let proto, let v):
            try c.encode("hello.ok", forKey: .t); try c.encode(proto, forKey: .proto)
            try c.encode(v, forKey: .soulVersion)
        case .event(let kind, let payload):
            try c.encode("event", forKey: .t); try c.encode(kind, forKey: .kind)
            try c.encode(payload, forKey: .payload)
        case .senseEvent(let p):
            try c.encode("sense.event", forKey: .t); try c.encode(p, forKey: .percept)
        case .chatUser(let s): try c.encode("chat.user", forKey: .t); try c.encode(s, forKey: .text)
        case .chatDelta(let s): try c.encode("chat.delta", forKey: .t); try c.encode(s, forKey: .text)
        case .chatDone: try c.encode("chat.done", forKey: .t)
        case .directive(let kind, let payload):
            try c.encode("directive", forKey: .t); try c.encode(kind, forKey: .kind)
            try c.encode(payload, forKey: .payload)
        case .toolCall(let id, let name, let args):
            try c.encode("tool.call", forKey: .t); try c.encode(id, forKey: .id)
            try c.encode(name, forKey: .name); try c.encode(args, forKey: .args)
        case .toolResult(let id, let ok, let content):
            try c.encode("tool.result", forKey: .t); try c.encode(id, forKey: .id)
            try c.encode(ok, forKey: .ok); try c.encode(content, forKey: .content)
        case .fuelReport(let date, let raw):
            try c.encode("fuel.report", forKey: .t); try c.encode(date, forKey: .date)
            try c.encode(raw, forKey: .raw)
        case .actionInvoke(let e, let a):
            try c.encode("action.invoke", forKey: .t); try c.encode(e, forKey: .eventId)
            try c.encode(a, forKey: .actionId)
        case .status: try c.encode("status", forKey: .t)
        case .statusOK(let f): try c.encode("status.ok", forKey: .t); try c.encode(f, forKey: .fields)
        case .ping: try c.encode("ping", forKey: .t)
        case .pong: try c.encode("pong", forKey: .t)
        case .bye: try c.encode("bye", forKey: .t)
        case .unknown(let t): try c.encode(t, forKey: .t)
        }
    }
}
