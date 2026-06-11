import XCTest
@testable import SoulCore

final class MilestoneTrackerTests: XCTestCase {
    func testCheckAnniversaryFindsMatch() {
        let cal = Calendar.current
        let lastYear = cal.date(byAdding: .year, value: -1, to: Date())!
        let m = Milestone(name: "第一天", date: lastYear)
        let result = MilestoneTracker.checkAnniversary(milestones: [m], today: Date())
        XCTAssertNotNil(result)
    }

    func testCheckAnniversaryNoMatch() {
        let m = Milestone(name: "test", date: Date().addingTimeInterval(-86400 * 30))
        XCTAssertNil(MilestoneTracker.checkAnniversary(milestones: [m]))
    }

    func testAnniversaryGreetingWithYears() {
        let cal = Calendar.current
        let twoYearsAgo = cal.date(byAdding: .year, value: -2, to: Date())!
        let m = Milestone(name: "出生日", date: twoYearsAgo)
        let greeting = MilestoneTracker.anniversaryGreeting(milestone: m)
        XCTAssertTrue(greeting.contains("2周年"))
    }

    func testDetectNewMilestones() {
        var g = GrowthState()
        g.stage = .juvenile
        g.streakDays = 30
        let ms = MilestoneTracker.detectNewMilestones(growth: g, bond: 100, existing: [])
        XCTAssertTrue(ms.count >= 3)
    }

    func testNoDuplicateMilestones() {
        var g = GrowthState()
        g.stage = .juvenile
        let existing = [Milestone(name: "长大成少年")]
        let ms = MilestoneTracker.detectNewMilestones(growth: g, bond: 0, existing: existing)
        XCTAssertFalse(ms.contains { $0.name == "长大成少年" })
    }
}
