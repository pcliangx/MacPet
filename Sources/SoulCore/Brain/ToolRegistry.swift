// Sources/SoulCore/Brain/ToolRegistry.swift
import Foundation

public typealias DirectiveSink = @Sendable (PeripheralMessage) -> Void

public struct ToolDefinition: Sendable {
    public let spec: ToolSpec
    public let handler: @Sendable ([String: JSONValue]) async -> JSONValue
    public init(spec: ToolSpec, handler: @escaping @Sendable ([String: JSONValue]) async -> JSONValue) {
        self.spec = spec; self.handler = handler
    }
}

public struct ToolOutcome: Sendable { public let ok: Bool; public let content: JSONValue }

/// 工具注册表：阶段门控（spec §6.1——成长在机制上真实），社交上下文禁用开关留作 M7 字段。
public actor ToolRegistry {
    private var defs: [String: ToolDefinition] = [:]

    public init() {}
    public func register(_ d: ToolDefinition) { defs[d.spec.name] = d }

    public func specs(stage: Stage) -> [ToolSpec] {
        defs.values.map(\.spec).filter { $0.minStage <= stage }.sorted { $0.name < $1.name }
    }

    public func dispatch(_ call: ToolCall) async -> ToolOutcome {
        guard let def = defs[call.name] else {
            return ToolOutcome(ok: false, content: .string("unknown tool: \(call.name)"))
        }
        let args: [String: JSONValue] =
            (try? JSONDecoder().decode([String: JSONValue].self, from: Data(call.arguments.utf8))) ?? [:]
        let content = await def.handler(args)
        return ToolOutcome(ok: true, content: content)
    }

    /// M0 核心工具：speak / emote（幼崽工具箱）
    public func registerCoreTools(sink: @escaping DirectiveSink) {
        register(ToolDefinition(
            spec: ToolSpec(name: "speak",
                           description: "对主人说一句话（气泡显示）。参数 text。",
                           parametersJSON: #"{"type":"object","properties":{"text":{"type":"string"}},"required":["text"]}"#,
                           minStage: .baby),
            handler: { args in
                let text = args["text"]?.stringValue ?? ""
                sink(.directive(kind: "speak", payload: ["text": .string(text)]))
                return .string("said")
            }))
        register(ToolDefinition(
            spec: ToolSpec(name: "emote",
                           description: "做一个动作/表情。参数 animation：idle|happy|sleepy|missing|alert。",
                           parametersJSON: #"{"type":"object","properties":{"animation":{"type":"string"}},"required":["animation"]}"#,
                           minStage: .baby),
            handler: { args in
                let anim = args["animation"]?.stringValue ?? "idle"
                sink(.directive(kind: "emote", payload: ["animation": .string(anim)]))
                return .string("emoted")
            }))
    }
}
