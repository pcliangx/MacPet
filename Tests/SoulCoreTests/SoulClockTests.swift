import XCTest
@testable import SoulCore

final class SoulClockTests: XCTestCase {
    func testTestClockAdvances() {
        let t0 = Date(timeIntervalSince1970: 1_750_000_000)
        let clock = TestClock(t0)
        clock.advance(by: 3600)
        XCTAssertEqual(clock.now.timeIntervalSince(t0), 3600)
    }
    func testMissedDaysAcrossSleep() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let f = ISO8601DateFormatter()
        let last = f.date(from: "2026-06-08T23:50:00+08:00")!
        let now  = f.date(from: "2026-06-11T00:10:00+08:00")!
        XCTAssertEqual(DayRollover.missedDays(from: last, to: now, calendar: cal), 3)
        XCTAssertEqual(DayRollover.missedDays(from: now, to: now, calendar: cal), 0)
    }
}
