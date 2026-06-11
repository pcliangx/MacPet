import XCTest
@testable import SoulCore

final class CapabilityProbeTests: XCTestCase {
    func testGoodProviderPasses() async {
        let good = ScriptedLLM(turns: [
            ChatMessage(role: .assistant, content: nil,
                        toolCalls: [ToolCall(id: "p1", name: "echo",
                                             arguments: #"{"text":"mpet-probe-7"}"#)]),
            ChatMessage(role: .assistant, content: "探测完成"),
        ])
        let r = await CapabilityProbe.run(provider: good)
        XCTAssertTrue(r.toolCallRoundtrip)
        XCTAssertTrue(r.argumentFidelity)
        XCTAssertTrue(r.streaming)
        XCTAssertTrue(r.usable)
    }
    func testProviderWithoutToolsFails() async {
        let bad = ScriptedLLM(turns: [
            ChatMessage(role: .assistant, content: "我不会调用工具，但我可以描述一下…"),
        ])
        let r = await CapabilityProbe.run(provider: bad)
        XCTAssertFalse(r.toolCallRoundtrip)
        XCTAssertFalse(r.usable)
    }
}
