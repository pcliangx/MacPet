import XCTest
@testable import SoulCore

final class FuelProcessorTests: XCTestCase {
    func testZeroRawGivesZeroXP() { XCTAssertEqual(FuelProcessor.process(raw: 0), 0) }
    func testLogDiminishing() {
        let xp1k = FuelProcessor.process(raw: 1_000)
        let xp10k = FuelProcessor.process(raw: 10_000)
        XCTAssertTrue(xp10k < xp1k * 10 && xp1k > 0)
    }
    func testMultipleFeedsCapped() {
        // Need sum large enough that log(1+sum)*3 >= fuelXPCap (80): sum >= e^(80/3) ≈ 5.2e11
        XCTAssertEqual(FuelProcessor.processMultiple(rawValues: [1e12, 1e12]), EconomyEngine.fuelXPCap)
    }
}
