import XCTest
@testable import SoulCore

final class AttentionSeekerTests: XCTestCase {
    func testShouldNotSeekWhenRecentlyInteracted() {
        XCTAssertFalse(AttentionSeeker(budgetPerHour: 2).shouldSeekAttention(idleMinutes: 5, phase: .active))
    }
    func testShouldSeekWhenIdleLongEnough() {
        XCTAssertTrue(AttentionSeeker(budgetPerHour: 2).shouldSeekAttention(idleMinutes: 35, phase: .active))
    }
    func testShouldNotSeekWhenAsleep() {
        XCTAssertFalse(AttentionSeeker(budgetPerHour: 2).shouldSeekAttention(idleMinutes: 120, phase: .asleep))
    }
    func testShouldNotSeekWhenReturning() {
        XCTAssertFalse(AttentionSeeker(budgetPerHour: 2).shouldSeekAttention(idleMinutes: 35, phase: .returning))
    }
    func testBudgetExhaustion() {
        let s = AttentionSeeker(budgetPerHour: 1)
        s.consumeAttention()
        XCTAssertFalse(s.shouldSeekAttention(idleMinutes: 35, phase: .active))
    }
    func testActionIsNonEmpty() {
        XCTAssertFalse(AttentionSeeker.pickAction(mood: .happy).isEmpty)
        XCTAssertFalse(AttentionSeeker.pickAction(mood: .sleepy).isEmpty)
    }
}
