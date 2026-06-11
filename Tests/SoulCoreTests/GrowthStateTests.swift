import XCTest
@testable import SoulCore

final class GrowthStateTests: XCTestCase {
    func testInitialState() {
        let g = GrowthState()
        XCTAssertEqual(g.totalXP, 0); XCTAssertEqual(g.stage, .baby); XCTAssertEqual(g.streakDays, 0)
    }
    func testStageForXPThresholds() {
        XCTAssertEqual(GrowthState.stageForXP(0), .baby)
        XCTAssertEqual(GrowthState.stageForXP(499), .baby)
        XCTAssertEqual(GrowthState.stageForXP(500), .juvenile)
        XCTAssertEqual(GrowthState.stageForXP(2499), .juvenile)
        XCTAssertEqual(GrowthState.stageForXP(2500), .adult)
        XCTAssertEqual(GrowthState.stageForXP(99999), .adult)
    }
    func testProgressToNext() {
        var g = GrowthState(); g.totalXP = 250
        XCTAssertEqual(g.progressToNext, 0.5, accuracy: 0.01)
        g.totalXP = 1500; g.stage = .juvenile
        XCTAssertEqual(g.progressToNext, 0.5, accuracy: 0.01)
    }
    func testShouldEvolve() {
        var g = GrowthState(); g.totalXP = 500
        XCTAssertTrue(g.shouldEvolve)
        g.stage = .juvenile; XCTAssertFalse(g.shouldEvolve)
    }
    func testCodableRoundTrip() throws {
        var g = GrowthState(); g.totalXP = 1234; g.bond = 42; g.streakDays = 7; g.stage = .juvenile
        let decoded = try JSONDecoder().decode(GrowthState.self, from: JSONEncoder().encode(g))
        XCTAssertEqual(decoded, g)
    }
}
