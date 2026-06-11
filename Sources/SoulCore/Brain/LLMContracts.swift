// Sources/SoulCore/Brain/LLMContracts.swift
import Foundation

public struct ToolCall: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let arguments: String              // OpenAI 线格式：参数是 JSON 字符串
    public init(id: String, name: String, arguments: String) {
        self.id = id; self.name = name; self.arguments = arguments
    }
    private enum K: String, CodingKey { case id, type, function }
    private enum F: String, CodingKey { case name, arguments }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        id = try c.decode(String.self, forKey: .id)
        let f = try c.nestedContainer(keyedBy: F.self, forKey: .function)
        name = try f.decode(String.self, forKey: .name)
        arguments = try f.decodeIfPresent(String.self, forKey: .arguments) ?? "{}"
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        try c.encode(id, forKey: .id)
        try c.encode("function", forKey: .type)
        var f = c.nestedContainer(keyedBy: F.self, forKey: .function)
        try f.encode(name, forKey: .name)
        try f.encode(arguments, forKey: .arguments)
    }
}

public struct ChatMessage: Codable, Equatable, Sendable {
    public enum Role: String, Codable, Sendable { case system, user, assistant, tool }
    public var role: Role
    public var content: String?
    public var toolCalls: [ToolCall]?
    public var toolCallID: String?
    private enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
        case toolCallID = "tool_call_id"
    }
    public init(role: Role, content: String?, toolCalls: [ToolCall]? = nil, toolCallID: String? = nil) {
        self.role = role; self.content = content
        self.toolCalls = toolCalls; self.toolCallID = toolCallID
    }
    public static func system(_ s: String) -> ChatMessage { .init(role: .system, content: s) }
    public static func user(_ s: String) -> ChatMessage { .init(role: .user, content: s) }
    public static func toolResult(callID: String, content: String) -> ChatMessage {
        .init(role: .tool, content: content, toolCallID: callID)
    }
}

public enum ToolTier: String, Codable, Sendable { case freeHome = "free-home", freeRead = "free-read", ask, never }
public enum Stage: Int, Codable, Sendable, Comparable {
    case egg = 0, baby = 1, juvenile = 2, adult = 3
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

public struct ToolSpec: Equatable, Sendable {
    public let name: String
    public let description: String
    public let parametersJSON: String         // JSON Schema 字符串
    public let tier: ToolTier
    public let minStage: Stage
    public init(name: String, description: String, parametersJSON: String,
                tier: ToolTier = .freeHome, minStage: Stage = .baby) {
        self.name = name; self.description = description
        self.parametersJSON = parametersJSON; self.tier = tier; self.minStage = minStage
    }
}

public struct LLMConfig: Codable, Equatable, Sendable {
    public var baseURL: URL
    public var apiKey: String
    public var model: String
    private enum CodingKeys: String, CodingKey { case baseURL, apiKey, model }  // 容忍多余字段
    public init(baseURL: URL, apiKey: String, model: String) {
        self.baseURL = baseURL; self.apiKey = apiKey; self.model = model
    }
}

/// 大脑供应商：流式文本经 onDelta，返回最终 assistant 消息（可能携带工具调用）
public protocol LLMProviding: Sendable {
    func complete(messages: [ChatMessage], tools: [ToolSpec],
                  onDelta: @escaping @Sendable (String) -> Void) async throws -> ChatMessage
}
