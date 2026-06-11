import XCTest
@testable import SoulCore

final class SanityTests: XCTestCase {
    func testVersion() { XCTAssertEqual(SoulCoreInfo.version, "0.2.0-m1") }
}
