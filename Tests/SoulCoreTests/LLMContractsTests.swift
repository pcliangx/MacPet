import XCTest
@testable import SoulCore

final class LLMContractsTests: XCTestCase {
    func testChatMessageWireFormat() throws {
        let m = ChatMessage(role: .assistant, content: nil,
                            toolCalls: [ToolCall(id: "c1", name: "speak", arguments: #"{"text":"hi"}"#)])
        let data = try JSONEncoder().encode(m)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains(#""role":"assistant""#))
        XCTAssertTrue(json.contains(#""tool_calls""#))
        XCTAssertTrue(json.contains(#""function""#))
        let back = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(back, m)
    }
    func testToolMessageCarriesCallID() throws {
        let m = ChatMessage.toolResult(callID: "c1", content: "ok")
        let json = String(data: try JSONEncoder().encode(m), encoding: .utf8)!
        XCTAssertTrue(json.contains(#""tool_call_id":"c1""#))
    }
    func testLLMConfigTolerantDecode() throws {
        let raw = #"{"baseURL":"https://api.x.com/v1","apiKey":"k","model":"m","futureField":1}"#
        let cfg = try JSONDecoder().decode(LLMConfig.self, from: Data(raw.utf8))
        XCTAssertEqual(cfg.model, "m")
    }
}
