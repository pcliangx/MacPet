import XCTest
@testable import SoulCore

final class MoodTests: XCTestCase {
    func testLongAwayMeansMissing() {
        let m = MoodEngine.mood(.init(attention: .away, hour: 15, secondsSinceInteraction: 3 * 3600))
        XCTAssertEqual(m, .missing)
    }
    func testNightMeansSleepy() {
        let m = MoodEngine.mood(.init(attention: .attending, hour: 1, secondsSinceInteraction: 3600))
        XCTAssertEqual(m, .sleepy)
    }
    func testRecentInteractionMeansHappy() {
        let m = MoodEngine.mood(.init(attention: .attending, hour: 15, secondsSinceInteraction: 120))
        XCTAssertEqual(m, .happy)
    }
    func testDefaultCalm() {
        let m = MoodEngine.mood(.init(attention: .elsewhere, hour: 15, secondsSinceInteraction: 3600))
        XCTAssertEqual(m, .calm)
    }
}
