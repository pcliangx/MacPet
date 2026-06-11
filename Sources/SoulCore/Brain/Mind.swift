// Sources/SoulCore/Brain/Mind.swift
import Foundation

/// 一颗心（spec §5.2 聊天合一 + 风险清单"一颗心并发模型"）：
/// 同一份历史、同一个人格；交互快车道（chat）抢占后台唤醒（wake）。
public actor Mind {
    private let provider: LLMProviding
    private let tools: ToolRegistry
    private let genome: Genome
    private let clock: SoulClock
    private var stage: Stage = .baby
    private var history: [ChatMessage] = []
    private let maxHistory = 40
    private var backgroundTask: Task<Void, Never>?
    public private(set) var lastBackgroundWasCancelled = false

    public var historyForTesting: [ChatMessage] { history }

    public init(provider: LLMProviding, tools: ToolRegistry, genome: Genome, clock: SoulClock) {
        self.provider = provider; self.tools = tools
        self.genome = genome; self.clock = clock
    }

    // ── 交互快车道 ──
    public func chat(_ text: String, mood: Mood, attention: Attention,
                     recent: [Percept], onDelta: @escaping @Sendable (String) -> Void) async throws {
        backgroundTask?.cancel()
        let rollbackMark = history.count
        history.append(.user(text))
        do {
            try await runAgentLoop(mood: mood, attention: attention, recent: recent,
                                   extra: nil, onDelta: onDelta)
        } catch {
            if history.count > rollbackMark { history.removeSubrange(rollbackMark...) }
            throw error
        }
    }

    // ── 后台唤醒（心跳/事件）──
    public func wake(reason: String, mood: Mood, attention: Attention, recent: [Percept]) async {
        backgroundTask?.cancel()
        let t = Task { [weak self] in
            guard let self else { return }
            await self.runBackground(reason: reason, mood: mood, attention: attention, recent: recent)
        }
        backgroundTask = t
        await t.value
        backgroundTask = nil
    }

    private func runBackground(reason: String, mood: Mood, attention: Attention, recent: [Percept]) async {
        lastBackgroundWasCancelled = false
        do {
            try await runAgentLoop(mood: mood, attention: attention, recent: recent,
                                   extra: "（你被唤醒了，原因：\(reason)。如果没什么值得说的就保持安静，调用 emote 即可。）",
                                   onDelta: { _ in })
        } catch is CancellationError {
            lastBackgroundWasCancelled = true
        } catch { }
    }

    // ── 共享 agent 循环：组装上下文 → LLM → 执行工具 → 喂回 → 直到无工具调用 ──
    private func runAgentLoop(mood: Mood, attention: Attention, recent: [Percept],
                              extra: String?, onDelta: @escaping @Sendable (String) -> Void) async throws {
        let hour = Calendar.current.component(.hour, from: clock.now)
        var system = PersonaSynth.systemPrompt(genome: genome, stage: stage, mood: mood,
                                               hour: hour, ownerPresent: attention != .away)
        if !recent.isEmpty {
            let digest = recent.suffix(8).map { "- \($0.kind)(\($0.priority.rawValue))" }.joined(separator: "\n")
            system += "\n近期发生的事：\n" + digest
        }
        if let extra { system += "\n" + extra }

        var messages: [ChatMessage] = [.system(system)] + history.suffix(maxHistory)
        let specs = await tools.specs(stage: stage)

        for _ in 0..<6 {
            try Task.checkCancellation()
            let reply = try await provider.complete(messages: messages, tools: specs, onDelta: onDelta)
            history.append(reply)
            messages.append(reply)
            guard let calls = reply.toolCalls, !calls.isEmpty else { return }
            for call in calls {
                try Task.checkCancellation()
                let outcome = await tools.dispatch(call)
                let resultText: String
                if case .string(let s) = outcome.content { resultText = s }
                else { resultText = outcome.ok ? "ok" : "error" }
                let msg = ChatMessage.toolResult(callID: call.id, content: resultText)
                history.append(msg)
                messages.append(msg)
            }
        }
    }
}
