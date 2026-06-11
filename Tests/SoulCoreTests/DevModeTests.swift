import XCTest
@testable import SoulCore

final class DevModeTests: XCTestCase {
    func testInjectXP() {
        var g = GrowthState()
        DevMode.injectXP(100, into: &g)
        XCTAssertEqual(g.totalXP, 100); XCTAssertEqual(g.todayXP, 100)
    }
    func testJumpToStage() {
        var g = GrowthState()
        DevMode.jumpToStage(.juvenile, state: &g)
        XCTAssertEqual(g.stage, .juvenile); XCTAssertEqual(g.totalXP, 500)
    }
    func testJumpToAdult() {
        var g = GrowthState()
        DevMode.jumpToStage(.adult, state: &g)
        XCTAssertEqual(g.stage, .adult); XCTAssertEqual(g.totalXP, 2500)
    }
    func testForceStreak() {
        var g = GrowthState(); DevMode.forceStreak(30, state: &g); XCTAssertEqual(g.streakDays, 30)
    }
    func testReset() {
        var g = GrowthState(); g.totalXP = 9999; g.bond = 99
        DevMode.resetGrowth(&g); XCTAssertEqual(g.totalXP, 0); XCTAssertEqual(g.bond, 0)
    }
}
