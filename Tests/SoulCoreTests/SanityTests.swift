import XCTest
@testable import SoulCore

final class SanityTests: XCTestCase {
    func testVersion() { XCTAssertEqual(SoulCoreInfo.version, "1.0.0-m9") }
}
