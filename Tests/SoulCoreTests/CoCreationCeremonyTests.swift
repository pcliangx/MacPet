import XCTest
@testable import SoulCore

final class CoCreationCeremonyTests: XCTestCase {
    func testEvolutionAnnouncement() {
        let p = CoCreationCeremony.evolutionAnnouncement(from: .baby, to: .juvenile, name: "泡沫")
        XCTAssertTrue(p.announcement.contains("幼崽"))
        XCTAssertTrue(p.announcement.contains("少年"))
        XCTAssertTrue(p.announcement.contains("泡沫"))
    }
    func testGenerateCandidatesCount() {
        let candidates = CoCreationCeremony.generateCandidates(from: .default, count: 3)
        XCTAssertEqual(candidates.count, 3)
    }
    func testCandidatesDifferFromOriginal() {
        let original = AppearanceGenome.default
        let candidates = CoCreationCeremony.generateCandidates(from: original, count: 5)
        // At least one candidate should differ in some parameter
        let hasDifferent = candidates.contains { $0 != original }
        XCTAssertTrue(hasDifferent)
    }
    func testCandidatesPreserveName() {
        let original = AppearanceGenome.default
        let candidates = CoCreationCeremony.generateCandidates(from: original)
        for c in candidates { XCTAssertEqual(c.petName, original.petName) }
    }
}
