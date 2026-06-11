import XCTest
@testable import SoulCore

final class MoodEngineV2Tests: XCTestCase {
    func testSleepingMoodWhenAsleep() {
        let m = MoodEngine.moodV2(.init(attention: .away, hour: 2,
            secondsSinceInteraction: 3600, phase: .asleep))
        XCTAssertEqual(m, .sleeping)
    }
    func testMissingStillWorksInActivePhase() {
        let m = MoodEngine.moodV2(.init(attention: .away, hour: 15,
            secondsSinceInteraction: 3 * 3600, phase: .active))
        XCTAssertEqual(m, .missing)
    }
    func testHappyOverridesActivePhase() {
        let m = MoodEngine.moodV2(.init(attention: .attending, hour: 15,
            secondsSinceInteraction: 60, phase: .active))
        XCTAssertEqual(m, .happy)
    }
    func testDrowsyPhaseMakesSleepy() {
        let m = MoodEngine.moodV2(.init(attention: .attending, hour: 1,
            secondsSinceInteraction: 300, phase: .drowsy))
        XCTAssertEqual(m, .sleepy)
    }
    func testBackwardCompatibleWithV1() {
        let m = MoodEngine.mood(.init(attention: .attending, hour: 15, secondsSinceInteraction: 60))
        XCTAssertEqual(m, .happy)
    }
    func testSleepingIsNewMood() {
        XCTAssertEqual(Mood.sleeping.rawValue, "sleeping")
    }
}
