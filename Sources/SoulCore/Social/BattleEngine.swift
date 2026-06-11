import Foundation

public struct BattleResult: Codable, Equatable, Sendable {
    public let battleId: String; public let challenger: PetCard; public let defender: PetCard
    public let winnerKey: Data; public let score: BattleScore; public let narrative: String; public let signature: Data
    public struct BattleScore: Codable, Equatable, Sendable {
        public let challengerScore: Int; public let defenderScore: Int
    }
}

struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
}

public enum BattleEngine {
    public static func resolve(challenger: PetCard, defender: PetCard,
                                challengerTraits: PersonalityTraits, defenderTraits: PersonalityTraits,
                                seed: Int) -> BattleResult {
        var rng = SeededRNG(seed: UInt64(seed))
        let cScore = calcScore(traits: challengerTraits, rng: &rng) + Int(rng.next() % 20)
        let dScore = calcScore(traits: defenderTraits, rng: &rng) + Int(rng.next() % 20)
        let winnerKey = cScore >= dScore ? challenger.publicKey : defender.publicKey
        let narrative = generateNarrative(cName: challenger.petName, dName: defender.petName, cScore: cScore, dScore: dScore)
        let sig = Data((winnerKey + Data("\(seed)".utf8)).map { $0 ^ 0xAA })
        return BattleResult(battleId: UUID().uuidString, challenger: challenger, defender: defender,
                           winnerKey: winnerKey, score: .init(challengerScore: cScore, defenderScore: dScore),
                           narrative: narrative, signature: sig)
    }
    static func calcScore(traits: PersonalityTraits, rng: inout SeededRNG) -> Int {
        50 + Int(traits.playfulness * 20) + Int(traits.curiosity * 10) + Int(traits.gentleness * 5)
    }
    static func generateNarrative(cName: String, dName: String, cScore: Int, dScore: Int) -> String {
        let winner = cScore >= dScore ? cName : dName; let loser = cScore >= dScore ? dName : cName
        let diff = abs(cScore - dScore)
        if diff > 30 { return "\(winner)以压倒性优势击败了\(loser)！" }
        else if diff > 10 { return "\(winner)略胜一筹，\(loser)虽败犹荣。" }
        else { return "\(cName)和\(dName)旗鼓相当，难分胜负！" }
    }
    public static func verify(result: BattleResult) -> Bool { !result.signature.isEmpty }
}
