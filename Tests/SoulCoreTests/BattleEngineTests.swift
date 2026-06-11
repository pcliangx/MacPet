import XCTest
@testable import SoulCore

final class BattleEngineTests: XCTestCase {
    func testDeterministic() {
        let c = PetCard(publicKey: Data([1,2,3]), petName: "A", species: "x")
        let d = PetCard(publicKey: Data([4,5,6]), petName: "B", species: "y")
        let r1 = BattleEngine.resolve(challenger: c, defender: d, challengerTraits: .default, defenderTraits: .default, seed: 42)
        let r2 = BattleEngine.resolve(challenger: c, defender: d, challengerTraits: .default, defenderTraits: .default, seed: 42)
        XCTAssertEqual(r1.score, r2.score)
        XCTAssertEqual(r1.winnerKey, r2.winnerKey)
    }
    func testPlayfulnessAffectsScore() {
        let c = PetCard(publicKey: Data([1,2,3]), petName: "A", species: "x")
        let d = PetCard(publicKey: Data([4,5,6]), petName: "B", species: "y")
        var highPlay = PersonalityTraits.default; highPlay.playfulness = 1.0
        var lowPlay = PersonalityTraits.default; lowPlay.playfulness = 0.0
        let rHigh = BattleEngine.resolve(challenger: c, defender: d, challengerTraits: highPlay, defenderTraits: lowPlay, seed: 42)
        XCTAssertTrue(rHigh.score.challengerScore > rHigh.score.defenderScore - 50) // high play should help
    }
    func testNarrativeGenerated() {
        let c = PetCard(publicKey: Data([1,2,3]), petName: "A", species: "x")
        let d = PetCard(publicKey: Data([4,5,6]), petName: "B", species: "y")
        let r = BattleEngine.resolve(challenger: c, defender: d, challengerTraits: .default, defenderTraits: .default, seed: 42)
        XCTAssertFalse(r.narrative.isEmpty)
        XCTAssertTrue(r.narrative.contains("A") || r.narrative.contains("B"))
    }
    func testVerify() {
        let c = PetCard(publicKey: Data([1,2,3]), petName: "A", species: "x")
        let d = PetCard(publicKey: Data([4,5,6]), petName: "B", species: "y")
        let r = BattleEngine.resolve(challenger: c, defender: d, challengerTraits: .default, defenderTraits: .default, seed: 42)
        XCTAssertTrue(BattleEngine.verify(result: r))
    }
    func testSignatureNotEmpty() {
        let c = PetCard(publicKey: Data([1,2,3]), petName: "A", species: "x")
        let d = PetCard(publicKey: Data([4,5,6]), petName: "B", species: "y")
        let r = BattleEngine.resolve(challenger: c, defender: d, challengerTraits: .default, defenderTraits: .default, seed: 1)
        XCTAssertFalse(r.signature.isEmpty)
    }
}
