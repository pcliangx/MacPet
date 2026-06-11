import XCTest
@testable import SoulCore

final class MemorySearchTests: XCTestCase {
    func testKeywordMatchRanksHigher() {
        let memories = [
            Memory(kind: .semantic, content: "主人喜欢熬夜写代码", tags: ["作息"]),
            Memory(kind: .episodic, content: "今天天气很好"),
        ]
        let results = MemorySearch.search(query: "熬夜", in: memories)
        XCTAssertEqual(results.first?.id, memories[0].id)
    }
    func testImportanceWeighting() {
        let memories = [
            Memory(kind: .episodic, content: "test", confidence: 1.0, importance: 1),
            Memory(kind: .episodic, content: "test", confidence: 1.0, importance: 5),
        ]
        let results = MemorySearch.search(query: "test", in: memories)
        XCTAssertEqual(results.first?.importance, 5)
    }
    func testConfidenceWeighting() {
        let memories = [
            Memory(kind: .semantic, content: "fact", confidence: 0.3),
            Memory(kind: .semantic, content: "fact", confidence: 0.9),
        ]
        let results = MemorySearch.search(query: "fact", in: memories)
        XCTAssertEqual(results.first?.confidence, 0.9)
    }
    func testEmptyQueryReturnsAll() {
        let memories = [Memory(kind: .episodic, content: "a"), Memory(kind: .episodic, content: "b")]
        XCTAssertEqual(MemorySearch.search(query: "", in: memories).count, 2)
    }
    func testLimitRespected() {
        let memories = (0..<10).map { Memory(kind: .episodic, content: "item \($0)") }
        XCTAssertEqual(MemorySearch.search(query: "item", in: memories, limit: 3).count, 3)
    }
}
