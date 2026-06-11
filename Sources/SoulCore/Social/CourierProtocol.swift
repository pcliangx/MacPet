import Foundation

public enum CourierMessage: Codable, Equatable, Sendable {
    case hello(nodeId: String)
    case helloOK(nodeId: String)
    case announcePresence(card: PetCard)
    case visitRequest(from: PetCard, toNodeId: String)
    case visitAccepted(visitorCard: PetCard)
    case visitRejected(reason: String)
    case battleChallenge(from: PetCard, battleId: String, seed: Int)
    case battleResult(battleId: String, winnerKey: Data, signature: Data)
    case gossip(peers: [PetCard])

    private enum K: String, CodingKey { case t, nodeId, card, toNodeId, visitorCard, reason, battleId, seed, winnerKey, signature, peers }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        let t = try c.decode(String.self, forKey: .t)
        switch t {
        case "hello": self = .hello(nodeId: try c.decode(String.self, forKey: .nodeId))
        case "hello.ok": self = .helloOK(nodeId: try c.decode(String.self, forKey: .nodeId))
        case "announce": self = .announcePresence(card: try c.decode(PetCard.self, forKey: .card))
        case "visit.request": self = .visitRequest(from: try c.decode(PetCard.self, forKey: .card), toNodeId: try c.decode(String.self, forKey: .toNodeId))
        case "visit.accepted": self = .visitAccepted(visitorCard: try c.decode(PetCard.self, forKey: .visitorCard))
        case "visit.rejected": self = .visitRejected(reason: try c.decode(String.self, forKey: .reason))
        case "battle.challenge": self = .battleChallenge(from: try c.decode(PetCard.self, forKey: .card), battleId: try c.decode(String.self, forKey: .battleId), seed: try c.decode(Int.self, forKey: .seed))
        case "battle.result": self = .battleResult(battleId: try c.decode(String.self, forKey: .battleId), winnerKey: try c.decode(Data.self, forKey: .winnerKey), signature: try c.decode(Data.self, forKey: .signature))
        case "gossip": self = .gossip(peers: try c.decode([PetCard].self, forKey: .peers))
        default: self = .hello(nodeId: "unknown")
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        switch self {
        case .hello(let n): try c.encode("hello", forKey: .t); try c.encode(n, forKey: .nodeId)
        case .helloOK(let n): try c.encode("hello.ok", forKey: .t); try c.encode(n, forKey: .nodeId)
        case .announcePresence(let card): try c.encode("announce", forKey: .t); try c.encode(card, forKey: .card)
        case .visitRequest(let from, let to): try c.encode("visit.request", forKey: .t); try c.encode(from, forKey: .card); try c.encode(to, forKey: .toNodeId)
        case .visitAccepted(let card): try c.encode("visit.accepted", forKey: .t); try c.encode(card, forKey: .visitorCard)
        case .visitRejected(let r): try c.encode("visit.rejected", forKey: .t); try c.encode(r, forKey: .reason)
        case .battleChallenge(let from, let id, let s): try c.encode("battle.challenge", forKey: .t); try c.encode(from, forKey: .card); try c.encode(id, forKey: .battleId); try c.encode(s, forKey: .seed)
        case .battleResult(let id, let w, let sig): try c.encode("battle.result", forKey: .t); try c.encode(id, forKey: .battleId); try c.encode(w, forKey: .winnerKey); try c.encode(sig, forKey: .signature)
        case .gossip(let peers): try c.encode("gossip", forKey: .t); try c.encode(peers, forKey: .peers)
        }
    }
}
