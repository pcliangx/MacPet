import XCTest
@testable import SoulCore

final class ReflexArcTests: XCTestCase {
    func testIntensityTable() {
        XCTAssertEqual(ReflexArc.intensity(attention: .attending, priority: .alert), .animate)
        XCTAssertEqual(ReflexArc.intensity(attention: .elsewhere, priority: .alert), .sound)
        XCTAssertEqual(ReflexArc.intensity(attention: .away,      priority: .alert), .notify)
        XCTAssertEqual(ReflexArc.intensity(attention: .attending, priority: .nudge), .silent)
        XCTAssertEqual(ReflexArc.intensity(attention: .away,      priority: .nudge), .animate)
        XCTAssertEqual(ReflexArc.intensity(attention: .attending, priority: .ambient), .silent)
    }
    func testAlertProducesNotifyDirectiveWhenAway() {
        let p = Percept(kind: "cc.waiting", priority: .alert,
                        payload: ["title": .string("CC 在等你")], at: Date())
        let ds = ReflexArc.directives(for: p, attention: .away, mood: .calm)
        guard case .directive(let kind, let payload) = ds.last else { return XCTFail("no directive") }
        XCTAssertEqual(kind, "notify")
        XCTAssertEqual(payload["title"]?.stringValue, "CC 在等你")
        guard case .directive(let k0, _) = ds.first else { return XCTFail() }
        XCTAssertEqual(k0, "emote")
    }
    func testAmbientProducesNothing() {
        let p = Percept(kind: "weather.tick", priority: .ambient, at: Date())
        XCTAssertTrue(ReflexArc.directives(for: p, attention: .attending, mood: .calm).isEmpty)
    }
}
