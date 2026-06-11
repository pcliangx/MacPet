import XCTest
@testable import SoulCore

final class AppearanceGenomeTests: XCTestCase {
    func testDefaultGenome() {
        let g = AppearanceGenome.default
        XCTAssertEqual(g.furHue, 28); XCTAssertEqual(g.petName, "泡沫"); XCTAssertTrue(g.blushEnabled)
    }
    func testRandomGenome() {
        let g = AppearanceGenome.random(name: "test")
        XCTAssertEqual(g.petName, "test")
        XCTAssertTrue(g.furHue >= 0 && g.furHue <= 360)
    }
    func testCodableRoundTrip() throws {
        let g = AppearanceGenome.default
        let decoded = try JSONDecoder().decode(AppearanceGenome.self, from: JSONEncoder().encode(g))
        XCTAssertEqual(decoded, g)
    }
    func testAllEnumCasesRoundTrip() throws {
        for ear in AppearanceGenome.EarShape.allCases {
            let g = AppearanceGenome.default; var g2 = g; g2.earShape = ear
            let d = try JSONDecoder().decode(AppearanceGenome.self, from: JSONEncoder().encode(g2))
            XCTAssertEqual(d.earShape, ear)
        }
    }
}
