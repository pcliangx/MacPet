import Foundation

/// M4 remember/recall 工具定义（juvenile+ 阶段门控）
public enum MemoryTools {
    public static let rememberSpec = ToolSpec(
        name: "remember",
        description: "记住一件事。参数 content（记忆内容）、kind（episodic/semantic/milestone，默认 episodic）、importance（1-5，默认 3）。",
        parametersJSON: #"{"type":"object","properties":{"content":{"type":"string"},"kind":{"type":"string","enum":["episodic","semantic","milestone"]},"importance":{"type":"integer"}},"required":["content"]}"#,
        minStage: .juvenile
    )

    public static let recallSpec = ToolSpec(
        name: "recall",
        description: "回忆相关的事。参数 query（搜索关键词）。返回最相关的记忆列表。",
        parametersJSON: #"{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}"#,
        minStage: .juvenile
    )

    public static func register(registry: ToolRegistry, memoryStore: MemoryStore) async {
        await registry.register(ToolDefinition(spec: rememberSpec) { args in
            let content = args["content"]?.stringValue ?? ""
            let kindStr = args["kind"]?.stringValue ?? "episodic"
            let kind = MemoryKind(rawValue: kindStr) ?? .episodic
            let importance = Int(args["importance"]?.doubleValue ?? 3)
            let memory = Memory(kind: kind, content: content, importance: importance)
            memoryStore.add(memory)
            return .string("记住了：\(content)")
        })
        await registry.register(ToolDefinition(spec: recallSpec) { args in
            let query = args["query"]?.stringValue ?? ""
            let results = MemorySearch.search(query: query, in: memoryStore.getAll(), limit: 3)
            if results.isEmpty { return .string("想不起来…") }
            let texts = results.map { "\($0.content)（置信度\($0.confidence)）" }
            results.forEach { memoryStore.recordAccess(id: $0.id) }
            return .string(texts.joined(separator: "；"))
        })
    }
}
