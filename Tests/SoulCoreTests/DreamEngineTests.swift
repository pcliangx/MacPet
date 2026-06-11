import XCTest
@testable import SoulCore

final class DreamEngineTests: XCTestCase {
    func testDistillGroupsByTopic() {
        let episodic = [
            Memory(kind: .episodic, content: "主人今天又熬夜了到很晚才睡觉"),
            Memory(kind: .episodic, content: "主人今天又熬夜了到很晚才回家"),
            Memory(kind: .episodic, content: "今天天气很好去散步了"),
        ]
        let semantic = DreamEngine.distill(episodic: episodic)
        // 两条共享前10字符"主人今天又熬夜了到很" → 蒸馏为一条语义
        XCTAssertTrue(semantic.count >= 1)
        XCTAssertEqual(semantic.first?.kind, .semantic)
    }
    func testDistillRequiresTwoOrMore() {
        let episodic = [Memory(kind: .episodic, content: "unique event xyz123")]
        let semantic = DreamEngine.distill(episodic: episodic)
        XCTAssertEqual(semantic.count, 0)  // 单条不蒸馏
    }
    func testMilestoneAtSevenDayStreak() {
        var g = GrowthState(); g.streakDays = 7
        let ms = DreamEngine.checkMilestones(growthState: g)
        XCTAssertTrue(ms.contains { $0.content.contains("7 天") })
    }
    func testNoMilestoneAtNormalDays() {
        var g = GrowthState(); g.streakDays = 3
        let ms = DreamEngine.checkMilestones(growthState: g)
        XCTAssertTrue(ms.isEmpty)
    }
}
