import XCTest
@testable import SoulCore

final class WakePolicyTests: XCTestCase {
    func percept(_ pr: PerceptPriority, clock: SoulClock) -> Percept {
        Percept(kind: "k", priority: pr, at: clock.now)
    }
    func testAlertAlwaysWakesAmbientNever() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let policy = WakePolicy(clock: clock, nudgeBudgetPerHour: 2)
        for _ in 0..<5 {
            let w = await policy.shouldWake(for: percept(.alert, clock: clock))
            XCTAssertTrue(w)
        }
        let amb = await policy.shouldWake(for: percept(.ambient, clock: clock))
        XCTAssertFalse(amb)
    }
    func testNudgeBudgetExhaustsAndResetsNextHour() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let policy = WakePolicy(clock: clock, nudgeBudgetPerHour: 2)
        let a = await policy.shouldWake(for: percept(.nudge, clock: clock))
        let b = await policy.shouldWake(for: percept(.nudge, clock: clock))
        let c = await policy.shouldWake(for: percept(.nudge, clock: clock))
        XCTAssertEqual([a, b, c], [true, true, false])
        clock.advance(by: 3601)
        let d = await policy.shouldWake(for: percept(.nudge, clock: clock))
        XCTAssertTrue(d)
    }
}
