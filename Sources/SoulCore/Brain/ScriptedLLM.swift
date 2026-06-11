// Sources/SoulCore/Brain/ScriptedLLM.swift
import Foundation

/// 测试架核心：脚本化回合、记录请求、可注入延迟（用于抢占/取消测试）
public actor ScriptedLLM: LLMProviding {
    public private(set) var requests: [[ChatMessage]] = []
    private var turns: [ChatMessage]
    private let delayNanos: UInt64

    public init(turns: [ChatMessage], delayNanos: UInt64 = 0) {
        self.turns = turns; self.delayNanos = delayNanos
    }

    public func complete(messages: [ChatMessage], tools: [ToolSpec],
                         onDelta: @escaping @Sendable (String) -> Void) async throws -> ChatMessage {
        requests.append(messages)
        if delayNanos > 0 { try await Task.sleep(nanoseconds: delayNanos) }
        try Task.checkCancellation()
        guard !turns.isEmpty else { return ChatMessage(role: .assistant, content: "…") }
        let turn = turns.removeFirst()
        if let text = turn.content, turn.toolCalls == nil {
            for ch in text { onDelta(String(ch)) }
        }
        return turn
    }
}
