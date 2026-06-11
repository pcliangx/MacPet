import XCTest
@testable import SoulCore

final class MemoryTests: XCTestCase {
    func testMemoryCreation() {
        let m = Memory(kind: .episodic, content: "主人今天聊了很久")
        XCTAssertEqual(m.kind, .episodic); XCTAssertEqual(m.confidence, 0.8)
    }
    func testMilestoneHighImportance() {
        XCTAssertEqual(Memory(kind: .milestone, content: "第一次聊天", importance: 5).importance, 5)
    }
    func testCodableRoundTrip() throws {
        let m = Memory(kind: .semantic, content: "主人喜欢熬夜", confidence: 0.6, importance: 4, tags: ["作息"])
        let decoded = try JSONDecoder().decode(Memory.self, from: JSONEncoder().encode(m))
        XCTAssertEqual(decoded.id, m.id); XCTAssertEqual(decoded.content, m.content)
    }
}
