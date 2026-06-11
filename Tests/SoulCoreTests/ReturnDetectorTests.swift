import XCTest
@testable import SoulCore

final class ReturnDetectorTests: XCTestCase {
    func testShortAbsenceNoGreeting() {
        XCTAssertNil(ReturnDetector.greeting(absenceMinutes: 15, phase: .active, mood: .calm))
    }
    func testMediumAbsenceReturnsCasualGreeting() {
        let g = ReturnDetector.greeting(absenceMinutes: 90, phase: .returning, mood: .calm)
        XCTAssertNotNil(g); XCTAssertTrue(g!.contains("回来"))
    }
    func testLongAbsenceReturnsWarmGreeting() {
        let g = ReturnDetector.greeting(absenceMinutes: 480, phase: .returning, mood: .missing)
        XCTAssertNotNil(g); XCTAssertTrue(g!.count > 5)
    }
    func testWakeUpGreeting() {
        let g = ReturnDetector.greeting(absenceMinutes: 480, phase: .returning, mood: .sleepy)
        XCTAssertNotNil(g)
    }
    func testNotReturningPhaseNoGreeting() {
        XCTAssertNil(ReturnDetector.greeting(absenceMinutes: 300, phase: .active, mood: .calm))
    }
    func testGreetingIncludesDuration() {
        let g = ReturnDetector.greeting(absenceMinutes: 180, phase: .returning, mood: .calm)
        XCTAssertNotNil(g); XCTAssertTrue(g!.contains("小时") || g!.contains("钟头") || g!.contains("一会"))
    }
}
