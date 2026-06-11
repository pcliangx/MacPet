import XCTest
@testable import SoulCore

final class IdleActionsTests: XCTestCase {
    func testPicksActionForActivePhase() {
        let (emote, _) = IdleActions.pick(phase: .active, mood: .calm)
        XCTAssertFalse(emote.isEmpty)
    }
    func testSleepingPhaseHasSleepEmote() {
        let (emote, _) = IdleActions.pick(phase: .asleep, mood: .sleepy)
        XCTAssertEqual(emote, "sleeping")
    }
    func testDrowsyPhaseIsSlow() {
        let (emote, _) = IdleActions.pick(phase: .drowsy, mood: .sleepy)
        XCTAssertTrue(["sleepy", "idle"].contains(emote))
    }
    func testAllCombinationsReturnEmote() {
        for phase in [LifecyclePhase.active, .drowsy, .asleep] {
            for mood in [Mood.calm, .happy, .sleepy, .missing] {
                let (emote, _) = IdleActions.pick(phase: phase, mood: mood)
                XCTAssertFalse(emote.isEmpty, "phase=\(phase) mood=\(mood)")
            }
        }
    }
    func testReturningPhaseReturnsIdle() {
        let (emote, speech) = IdleActions.pick(phase: .returning, mood: .calm)
        XCTAssertEqual(emote, "idle")
        XCTAssertNil(speech)
    }
}
