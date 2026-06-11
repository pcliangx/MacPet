// Sources/SoulCore/Probe/CapabilityProbe.swift
import Foundation

public struct ProbeReport: Codable, Sendable {
    public var toolCallRoundtrip = false   // 会不会按指示调用工具
    public var argumentFidelity = false    // 参数 JSON 是否原样保真
    public var streaming = false           // 是否收到增量
    public var notes: [String] = []
    public var usable: Bool { toolCallRoundtrip && argumentFidelity }
}

/// 硬约束 §12.1：配置任意 OpenAI 兼容端点时实测，不合格就明说。
public enum CapabilityProbe {
    public static func run(provider: LLMProviding) async -> ProbeReport {
        var report = ProbeReport()
        let echoTool = ToolSpec(
            name: "echo", description: "原样回显参数 text",
            parametersJSON: #"{"type":"object","properties":{"text":{"type":"string"}},"required":["text"]}"#)
        let probeMessages: [ChatMessage] = [
            .system("你是协议探测器。收到指令后必须调用 echo 工具，参数 text 设为收到的暗号，不要做别的。"),
            .user("暗号是 mpet-probe-7，请调用 echo。"),
        ]
        do {
            let r1 = try await provider.complete(messages: probeMessages, tools: [echoTool], onDelta: { _ in })
            if let call = r1.toolCalls?.first(where: { $0.name == "echo" }) {
                report.toolCallRoundtrip = true
                if call.arguments.contains("mpet-probe-7") { report.argumentFidelity = true }
                else { report.notes.append("工具参数未保真：\(call.arguments)") }
                var sawDelta = false
                _ = try await provider.complete(
                    messages: probeMessages + [r1, .toolResult(callID: call.id, content: "mpet-probe-7")],
                    tools: [echoTool], onDelta: { _ in sawDelta = true })
                report.streaming = sawDelta
            } else {
                report.notes.append("端点未发起工具调用（content=\(r1.content ?? "nil"))")
            }
        } catch {
            report.notes.append("探测请求失败：\(error)")
        }
        return report
    }
}
