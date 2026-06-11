import XCTest
@testable import SoulCore

final class HeartbeatSchedulerTests: XCTestCase {
    func testDoesNotFireTooOften() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let s = HeartbeatScheduler(clock: clock, intervalMinutes: 30, dailyBudget: 12)
        let t1 = await s.shouldFire()
        clock.advance(by: 60)
        let t2 = await s.shouldFire()
        XCTAssertTrue(t1)
        XCTAssertFalse(t2)
    }
    func testFiresAtInterval() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let s = HeartbeatScheduler(clock: clock, intervalMinutes: 30, dailyBudget: 12)
        let t1 = await s.shouldFire()
        clock.advance(by: 31 * 60)
        let t2 = await s.shouldFire()
        XCTAssertTrue(t1)
        XCTAssertTrue(t2)
    }
    func testDailyBudgetExhaustion() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let s = HeartbeatScheduler(clock: clock, intervalMinutes: 30, dailyBudget: 2)
        _ = await s.shouldFire()
        clock.advance(by: 31 * 60)
        _ = await s.shouldFire()
        clock.advance(by: 31 * 60)
        let t3 = await s.shouldFire()
        XCTAssertFalse(t3)
    }
    func testBudgetResetsNextDay() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let s = HeartbeatScheduler(clock: clock, intervalMinutes: 30, dailyBudget: 1)
        _ = await s.shouldFire()
        clock.advance(by: 31 * 60)
        let blocked = await s.shouldFire()
        XCTAssertFalse(blocked)
        clock.advance(by: 86_400)
        let reset = await s.shouldFire()
        XCTAssertTrue(reset)
    }
    func testSkipsWhenUserIsActive() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let s = HeartbeatScheduler(clock: clock, intervalMinutes: 30, dailyBudget: 12)
        let r = await s.shouldFire(lastInteractionMinutesAgo: 5)
        XCTAssertFalse(r)
    }
}
