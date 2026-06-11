import XCTest
@testable import SoulCore

final class ScriptedLLMTests: XCTestCase {
    func testPopsTurnsAndRecordsRequests() async throws {
        let fake = ScriptedLLM(turns: [
            ChatMessage(role: .assistant, content: nil,
                        toolCalls: [ToolCall(id: "c1", name: "speak", arguments: #"{"text":"嘞！"}"#)]),
            ChatMessage(role: .assistant, content: "好啦"),
        ])
        var deltas: [String] = []
        let r1 = try await fake.complete(messages: [.user("hi")], tools: [], onDelta: { deltas.append($0) })
        XCTAssertEqual(r1.toolCalls?.first?.name, "speak")
        let r2 = try await fake.complete(messages: [], tools: [], onDelta: { _ in })
        XCTAssertEqual(r2.content, "好啦")
        let seen = await fake.requests
        XCTAssertEqual(seen.count, 2)
        XCTAssertEqual(deltas, [])
    }
    func testStreamsContentAsDeltas() async throws {
        let fake = ScriptedLLM(turns: [ChatMessage(role: .assistant, content: "你好呀")])
        var got = ""
        _ = try await fake.complete(messages: [], tools: [], onDelta: { got += $0 })
        XCTAssertEqual(got, "你好呀")
    }
}
