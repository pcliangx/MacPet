import XCTest
@testable import SoulCore

final class EconomyEngineTests: XCTestCase {
    func testBasePresenceOnly() { XCTAssertEqual(EconomyEngine.calcXPGain(), 10) }
    func testFuelIsDiminished() {
        let xp = EconomyEngine.calcXPGain(fuelRaw: 10000)
        XCTAssertTrue(xp <= EconomyEngine.dailyXPCap && xp > 10)
    }
    func testDailyCapEnforced() {
        // When todayXPSoFar == dailyXPCap, no more XP can be earned
        let xp = EconomyEngine.calcXPGain(fuelRaw: 99999, interactionBonuses: 100, chatBonuses: 100, todayXPSoFar: EconomyEngine.dailyXPCap)
        XCTAssertEqual(xp, 0)
    }
    func testDailyCapWithExistingXP() {
        XCTAssertEqual(EconomyEngine.calcXPGain(todayXPSoFar: 140), 10)
    }
    func testStreakMultiplier() {
        XCTAssertEqual(EconomyEngine.streakMultiplier(days: 100), 1.5)
        XCTAssertEqual(EconomyEngine.streakMultiplier(days: 0), 1.0)
        XCTAssertEqual(EconomyEngine.streakMultiplier(days: 7), 1.2)
    }
    func testBondGain() {
        XCTAssertEqual(EconomyEngine.bondGain(for: .chat), 2)
        XCTAssertEqual(EconomyEngine.bondGain(for: .respondToCall), 5)
    }
}
