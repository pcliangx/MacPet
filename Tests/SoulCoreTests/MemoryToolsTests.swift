import XCTest
@testable import SoulCore

final class MemoryToolsTests: XCTestCase {
    func testRememberSpecIsJuvenileGated() {
        XCTAssertEqual(MemoryTools.rememberSpec.minStage, .juvenile)
    }
    func testRecallSpecIsJuvenileGated() {
        XCTAssertEqual(MemoryTools.recallSpec.minStage, .juvenile)
    }
    func testRememberHandlerCreatesMemory() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = MemoryStore(directory: dir)
        let reg = ToolRegistry()
        await MemoryTools.register(registry: reg, memoryStore: store)
        let result = await reg.dispatch(ToolCall(id: "r1", name: "remember",
            arguments: #"{"content":"主人喜欢喝茶","kind":"semantic","importance":4}"#))
        XCTAssertTrue(result.ok)
        XCTAssertEqual(store.count(), 1)
        XCTAssertEqual(store.getAll().first?.content, "主人喜欢喝茶")
    }
    func testRecallHandlerSearchesMemory() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = MemoryStore(directory: dir)
        store.add(Memory(kind: .semantic, content: "主人喜欢喝茶", confidence: 0.9))
        let reg = ToolRegistry()
        await MemoryTools.register(registry: reg, memoryStore: store)
        let result = await reg.dispatch(ToolCall(id: "r2", name: "recall", arguments: #"{"query":"喝茶"}"#))
        XCTAssertTrue(result.ok)
        if case .string(let s) = result.content { XCTAssertTrue(s.contains("喝茶")) }
    }
    func testRecallEmptyStoreReturnsCantRemember() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = MemoryStore(directory: dir)
        let reg = ToolRegistry()
        await MemoryTools.register(registry: reg, memoryStore: store)
        let result = await reg.dispatch(ToolCall(id: "r3", name: "recall", arguments: #"{"query":"nothing"}"#))
        XCTAssertTrue(result.ok)
        if case .string(let s) = result.content { XCTAssertTrue(s.contains("想不起来")) }
    }
}
