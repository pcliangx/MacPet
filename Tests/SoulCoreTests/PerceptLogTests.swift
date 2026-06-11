import XCTest
@testable import SoulCore

final class PerceptLogTests: XCTestCase {
    func testCoalescesSameKindAmbientWithinWindow() {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let log = PerceptLog(capacity: 10, coalesceWindow: 60, clock: clock)
        log.add(Percept(kind: "weather.tick", priority: .ambient, at: clock.now))
        clock.advance(by: 10)
        log.add(Percept(kind: "weather.tick", priority: .ambient, at: clock.now))
        XCTAssertEqual(log.recent(limit: 10).count, 1)          // 合并了
        clock.advance(by: 120)
        log.add(Percept(kind: "weather.tick", priority: .ambient, at: clock.now))
        XCTAssertEqual(log.recent(limit: 10).count, 2)          // 窗口外不合并
    }
    func testAlertNeverCoalescedAndCapacityBounds() {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let log = PerceptLog(capacity: 3, coalesceWindow: 60, clock: clock)
        for _ in 0..<5 { log.add(Percept(kind: "cc.waiting", priority: .alert, at: clock.now)) }
        XCTAssertEqual(log.recent(limit: 10).count, 3)          // 容量封顶，alert 不合并
    }
}
