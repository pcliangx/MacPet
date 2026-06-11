import XCTest
@testable import SoulCore

final class MindTests: XCTestCase {
    func makeMind(provider: LLMProviding, sink: @escaping DirectiveSink) async -> Mind {
        let reg = ToolRegistry()
        await reg.registerCoreTools(sink: sink)
        return Mind(provider: provider, tools: reg, genome: .default,
                    clock: TestClock(Date(timeIntervalSince1970: 1_750_000_000)))
    }

    func testChatRunsToolLoopThenFinishes() async throws {
        nonisolated(unsafe) var directives: [PeripheralMessage] = []
        let fake = ScriptedLLM(turns: [
            ChatMessage(role: .assistant, content: nil,
                        toolCalls: [ToolCall(id: "c1", name: "speak", arguments: #"{"text":"嘞！主人！"}"#)]),
            ChatMessage(role: .assistant, content: "（蹭了蹭）"),
        ])
        let mind = await makeMind(provider: fake, sink: { directives.append($0) })
        var deltas = ""
        try await mind.chat("你好呀", mood: .happy, attention: .attending,
                            recent: [], onDelta: { deltas += $0 })
        XCTAssertEqual(directives.count, 1)
        XCTAssertEqual(deltas, "（蹭了蹭）")
        let reqs = await fake.requests
        XCTAssertEqual(reqs.count, 2)
        XCTAssertEqual(reqs[1].last?.role, .tool)
    }

    func testChatPreemptsBackgroundWake() async throws {
        let slow = ScriptedLLM(turns: [ChatMessage(role: .assistant, content: "后台沉思")],
                               delayNanos: 500_000_000)
        let mind = await makeMind(provider: slow, sink: { _ in })
        let bg = Task { await mind.wake(reason: "heartbeat", mood: .calm, attention: .away, recent: []) }
        try await Task.sleep(nanoseconds: 50_000_000)
        try await mind.chat("在吗", mood: .calm, attention: .attending, recent: [], onDelta: { _ in })
        await bg.value
        let cancelled = await mind.lastBackgroundWasCancelled
        XCTAssertTrue(cancelled)
    }

    func testChatErrorRollsBackOptimisticUserTurn() async {
        struct Boom: LLMProviding {
            func complete(messages: [ChatMessage], tools: [ToolSpec],
                          onDelta: @escaping @Sendable (String) -> Void) async throws -> ChatMessage {
                throw OpenAILLMClient.LLMError.http(500)
            }
        }
        let mind = await makeMind(provider: Boom(), sink: { _ in })
        do {
            try await mind.chat("hi", mood: .calm, attention: .attending, recent: [], onDelta: { _ in })
            XCTFail("should throw")
        } catch {}
        let history = await mind.historyForTesting
        XCTAssertFalse(history.contains { $0.role == .user })
    }

    func testRollbackRemovesPartialToolExchangeOnLaterFailure() async {
        actor FlakyProvider: LLMProviding {
            private var n = 0
            func complete(messages: [ChatMessage], tools: [ToolSpec],
                          onDelta: @escaping @Sendable (String) -> Void) async throws -> ChatMessage {
                n += 1
                if n == 1 {
                    return ChatMessage(role: .assistant, content: nil,
                                       toolCalls: [ToolCall(id: "c1", name: "speak", arguments: #"{"text":"hi"}"#)])
                }
                throw OpenAILLMClient.LLMError.http(500)   // 第二轮（喂回工具结果后）失败
            }
        }
        let mind = await makeMind(provider: FlakyProvider(), sink: { _ in })
        do {
            try await mind.chat("hi", mood: .calm, attention: .attending, recent: [], onDelta: { _ in })
            XCTFail("should throw")
        } catch {}
        let history = await mind.historyForTesting
        XCTAssertTrue(history.isEmpty, "partial tool exchange + user turn must all roll back; got \(history.map(\.role))")
    }
}
