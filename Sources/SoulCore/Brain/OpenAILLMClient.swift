// Sources/SoulCore/Brain/OpenAILLMClient.swift
import Foundation

/// OpenAI 兼容 chat/completions 客户端：流式 SSE + 工具调用。永不写死厂商（spec §12.1）。
public final class OpenAILLMClient: LLMProviding, @unchecked Sendable {
    private let config: LLMConfig
    private let session: URLSession
    public init(config: LLMConfig, session: URLSession = .shared) {
        self.config = config; self.session = session
    }

    public func complete(messages: [ChatMessage], tools: [ToolSpec],
                         onDelta: @escaping @Sendable (String) -> Void) async throws -> ChatMessage {
        var req = URLRequest(url: config.baseURL.appendingPathComponent("chat/completions"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try Self.requestBody(model: config.model, messages: messages, tools: tools)

        let (bytes, response) = try await session.bytes(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            bytes.task.cancel()
            throw LLMError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        var content = ""
        var calls: [Int: (id: String, name: String, args: String)] = [:]
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                  let delta = chunk.choices.first?.delta else { continue }
            if let text = delta.content, !text.isEmpty { content += text; onDelta(text) }
            for tc in delta.toolCalls ?? [] {
                var cur = calls[tc.index] ?? (id: "", name: "", args: "")
                if let id = tc.id { cur.id = id }
                if let n = tc.function?.name { cur.name += n }
                if let a = tc.function?.arguments { cur.args += a }
                calls[tc.index] = cur
            }
        }
        let toolCalls = calls.isEmpty ? nil : calls.sorted { $0.key < $1.key }
            .map { ToolCall(id: $0.value.id, name: $0.value.name, arguments: $0.value.args) }
        return ChatMessage(role: .assistant, content: content.isEmpty ? nil : content, toolCalls: toolCalls)
    }

    static func requestBody(model: String, messages: [ChatMessage], tools: [ToolSpec]) throws -> Data {
        var dict: [String: Any] = [
            "model": model, "stream": true,
            "messages": try messages.map {
                try JSONSerialization.jsonObject(with: JSONEncoder().encode($0))
            },
        ]
        if !tools.isEmpty {
            dict["tools"] = try tools.map {
                ["type": "function",
                 "function": ["name": $0.name, "description": $0.description,
                              "parameters": try JSONSerialization.jsonObject(with: Data($0.parametersJSON.utf8))]]
            }
        }
        return try JSONSerialization.data(withJSONObject: dict)
    }

    public enum LLMError: Error, Equatable { case http(Int) }

    private struct StreamChunk: Decodable {
        struct Choice: Decodable { let delta: Delta? }
        struct Delta: Decodable {
            let content: String?
            let toolCalls: [TCDelta]?
            enum CodingKeys: String, CodingKey { case content, toolCalls = "tool_calls" }
        }
        struct TCDelta: Decodable {
            let index: Int; let id: String?; let function: FDelta?
        }
        struct FDelta: Decodable { let name: String?; let arguments: String? }
        let choices: [Choice]
    }
}
