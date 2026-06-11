import XCTest
@testable import SoulCore

final class PersonalityDriftTests: XCTestCase {
    func testChattyInteraction() {
        let t = PersonalityDrift.drift(traits: .default, interactions: .init(chatCount: 10))
        XCTAssertTrue(t.talkativeness > 0.5)
    }

    func testQuietInteraction() {
        let t = PersonalityDrift.drift(traits: .default, interactions: .init(chatCount: 0))
        XCTAssertTrue(t.talkativeness < 0.5)
    }

    func testNightOwlDrift() {
        let t = PersonalityDrift.drift(traits: .default, interactions: .init(lateNightActivity: true))
        XCTAssertEqual(t.nightOwl, 0.55, accuracy: 0.001)
    }

    func testDescribeChatty() {
        var t = PersonalityTraits.default
        t.talkativeness = 0.8
        XCTAssertTrue(PersonalityDrift.describe(t).contains("话有点多"))
    }

    func testDescribeDefault() {
        XCTAssertEqual(PersonalityDrift.describe(.default), "性格平和")
    }

    func testTraitsClamped() {
        var t = PersonalityTraits.default
        t.talkativeness = 0.99
        let drifted = PersonalityDrift.drift(traits: t, interactions: .init(chatCount: 10))
        XCTAssertLessThanOrEqual(drifted.talkativeness, 1.0)
    }
}
