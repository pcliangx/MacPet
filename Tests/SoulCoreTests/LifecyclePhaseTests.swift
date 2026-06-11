import XCTest
@testable import SoulCore

final class LifecyclePhaseTests: XCTestCase {
    func testActiveDuringDaytime() {
        XCTAssertEqual(LifecyclePhase.resolve(hour: 14, idleMinutes: 5, wasAsleep: false), .active)
    }
    func testDrowsyLateNightStillAwake() {
        XCTAssertEqual(LifecyclePhase.resolve(hour: 1, idleMinutes: 30, wasAsleep: false), .drowsy)
    }
    func testAsleepLateNightIdle() {
        XCTAssertEqual(LifecyclePhase.resolve(hour: 2, idleMinutes: 120, wasAsleep: false), .asleep)
    }
    func testReturningAfterLongAbsence() {
        XCTAssertEqual(LifecyclePhase.resolve(hour: 14, idleMinutes: 180, wasAsleep: false), .returning)
    }
    func testWakingUpFromSleep() {
        XCTAssertEqual(LifecyclePhase.resolve(hour: 8, idleMinutes: 5, wasAsleep: true), .returning)
    }
    func testStaysAsleepDuringDaytimeNap() {
        XCTAssertEqual(LifecyclePhase.resolve(hour: 14, idleMinutes: 5, wasAsleep: true), .asleep)
    }
}
