import XCTest
@testable import SoulCore

final class ToolRegistryTests: XCTestCase {
    func testStageGatingFiltersSpecs() async {
        let reg = ToolRegistry()
        await reg.register(ToolDefinition(
            spec: ToolSpec(name: "recall", description: "回忆", parametersJSON: "{}", minStage: .juvenile),
            handler: { _ in .null }))
        await reg.register(ToolDefinition(
            spec: ToolSpec(name: "speak", description: "说话", parametersJSON: "{}", minStage: .baby),
            handler: { _ in .null }))
        let babyTools = await reg.specs(stage: .baby)
        XCTAssertEqual(babyTools.map(\.name), ["speak"])
        let juvTools = await reg.specs(stage: .juvenile)
        XCTAssertEqual(Set(juvTools.map(\.name)), ["speak", "recall"])
    }
    func testSpeakToolEmitsDirective() async throws {
        nonisolated(unsafe) var captured: [PeripheralMessage] = []
        let reg = ToolRegistry()
        await reg.registerCoreTools(sink: { captured.append($0) })
        let result = await reg.dispatch(ToolCall(id: "c1", name: "speak", arguments: #"{"text":"嘞！"}"#))
        XCTAssertEqual(result.ok, true)
        guard case .directive(let kind, let payload) = captured.first else { return XCTFail() }
        XCTAssertEqual(kind, "speak")
        XCTAssertEqual(payload["text"]?.stringValue, "嘞！")
    }
    func testUnknownToolReturnsError() async {
        let reg = ToolRegistry()
        let r = await reg.dispatch(ToolCall(id: "c9", name: "nope", arguments: "{}"))
        XCTAssertEqual(r.ok, false)
    }
}
