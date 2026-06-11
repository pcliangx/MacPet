# M7 它有朋友了 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development

**Goal:** 身份密钥 + ticket 加好友 + 好友存储 + 串门协议 + 双签名异步对战 + 宿敌 + 无账号系统——它有了自己的社交生活。

**Architecture:** `PetIdentity`（密钥对+公钥名片）+ `FriendTicket`（加好友凭证编解码）+ `FriendStore`（好友/宿敌持久化）+ `CourierProtocol`（Swift↔courier.sock 接口）+ `BattleEngine`（数值底盘+性格演出+双签名）+ 档案导出扩展（含身份密钥）。

**对应 spec：** §9.1 宠物身份与名片 · §9.2 信使与轻基建 · §9.3 加好友与串门 · §9.4 对战 · §12 #2 档案导出含密钥。

**M7 不做**：真正的 iroh Rust 实现（mpet-courier 为独立 Rust crate，M7 只定义 Swift 侧协议和数据模型）；广场（M8）；社交礼仪安全（M8）。

---

## 文件结构

```
Sources/SoulCore/
  Social/PetIdentity.swift           # NEW: 身份密钥对 + 名片
  Social/FriendTicket.swift          # NEW: 加好友凭证
  Social/FriendStore.swift           # NEW: 好友/宿敌存储
  Social/CourierProtocol.swift       # NEW: Swift↔courier 消息协议
  Social/BattleEngine.swift          # NEW: 对战引擎
Tests/SoulCoreTests/
  PetIdentityTests.swift             # NEW
  FriendTicketTests.swift            # NEW
  FriendStoreTests.swift             # NEW
  BattleEngineTests.swift            # NEW
```

---

### Task 0: PetIdentity（身份密钥对）

```swift
// Sources/SoulCore/Social/PetIdentity.swift
import Foundation
import Security

public struct PetIdentity: Codable, Equatable, Sendable {
    public let publicKey: Data          // 公钥（用于名片、验证签名）
    public let privateKey: Data         // 私钥（用于签名，进 Keychain）
    public let petName: String
    public let species: String
    public let createdAt: Date

    /// 生成新身份（孵化时调用）
    public static func generate(petName: String, species: String) -> PetIdentity {
        // 简化版：用随机 32 字节作为密钥对（真实实现用 Ed25519）
        let pub = randomBytes(32)
        let priv = randomBytes(64)
        return PetIdentity(publicKey: pub, privateKey: priv, petName: petName, species: species, createdAt: Date())
    }

    /// 生成名片（公开信息，可分享给好友）
    public func card() -> PetCard {
        PetCard(publicKey: publicKey, petName: petName, species: species)
    }

    /// 签名数据
    public func sign(_ data: Data) -> Data {
        // 简化版签名：HMAC(privateKey, data)（真实实现用 Ed25519）
        var hmac = Data()
        for (i, byte) in data.enumerated() {
            hmac.append(byte ^ privateKey[i % privateKey.count])
        }
        return hmac
    }

    /// 验证签名
    public static func verify(signature: Data, data: Data, publicKey: Data) -> Bool {
        // 简化版：实际用公钥验证 Ed25519 签名
        return signature.count == data.count
    }

    private static func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }
}

public struct PetCard: Codable, Equatable, Sendable {
    public let publicKey: Data
    public let petName: String
    public let species: String
}
```

### Task 1: FriendTicket（加好友凭证）

```swift
// Sources/SoulCore/Social/FriendTicket.swift
import Foundation

public struct FriendTicket: Codable, Equatable, Sendable {
    public let fromCard: PetCard
    public let nonce: Data
    public let signature: Data
    public let createdAt: Date

    /// 生成好友 ticket（发起方签名）
    public static func create(from identity: PetIdentity) -> FriendTicket {
        let card = identity.card()
        let nonce = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        var payload = card.publicKey + nonce
        let sig = identity.sign(payload)
        return FriendTicket(fromCard: card, nonce: nonce, signature: sig, createdAt: Date())
    }

    /// 编码为可分享字符串（base64）
    public func encode() -> String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return data.base64EncodedString()
    }

    /// 从字符串解码
    public static func decode(_ str: String) -> FriendTicket? {
        guard let data = Data(base64Encoded: str) else { return nil }
        return try? JSONDecoder().decode(FriendTicket.self, from: data)
    }

    /// 验证 ticket 签名
    public func isValid() -> Bool {
        var payload = fromCard.publicKey + nonce
        return PetIdentity.verify(signature: signature, data: payload, publicKey: fromCard.publicKey)
    }
}
```

### Task 2: FriendStore（好友存储）

```swift
// Sources/SoulCore/Social/FriendStore.swift
import Foundation

public struct Friend: Codable, Equatable, Sendable, Identifiable {
    public let id: String  // = card.publicKey.base64
    public var card: PetCard
    public var relationship: Relationship
    public var addedAt: Date
    public var lastSeen: Date?
    public var battleRecord: BattleRecord

    public enum Relationship: String, Codable, Sendable { case friend, rival, stranger }

    public struct BattleRecord: Codable, Equatable, Sendable {
        public var wins: Int = 0; public var losses: Int = 0; public var draws: Int = 0
    }
}

public final class FriendStore: @unchecked Sendable {
    private let dir: URL; private let lock = NSLock(); private var friends: [Friend] = []
    private var fileURL: URL { dir.appendingPathComponent("friends.json") }

    public init(directory: URL) {
        self.dir = directory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: fileURL),
           let f = try? JSONDecoder().decode([Friend].self, from: data) { friends = f }
    }

    public func addFriend(from ticket: FriendTicket) -> Friend {
        lock.lock(); defer { lock.unlock() }
        let id = ticket.fromCard.publicKey.base64EncodedString()
        if let existing = friends.first(where: { $0.id == id }) { return existing }
        let friend = Friend(id: id, card: ticket.fromCard, relationship: .friend,
                           addedAt: Date(), lastSeen: nil, battleRecord: .init())
        friends.append(friend); save(); return friend
    }

    public func setRival(id: String) {
        lock.lock(); defer { lock.unlock() }
        guard let idx = friends.firstIndex(where: { $0.id == id }) else { return }
        friends[idx].relationship = .rival; save()
    }

    public func updateLastSeen(id: String) {
        lock.lock(); defer { lock.unlock() }
        guard let idx = friends.firstIndex(where: { $0.id == id }) else { return }
        friends[idx].lastSeen = Date(); save()
    }

    public func updateBattle(id: String, won: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard let idx = friends.firstIndex(where: { $0.id == id }) else { return }
        if won { friends[idx].battleRecord.wins += 1 } else { friends[idx].battleRecord.losses += 1 }
        save()
    }

    public func getAll() -> [Friend] { lock.lock(); defer { lock.unlock() }; return friends }
    public func friendCount() -> Int { getAll().filter { $0.relationship == .friend }.count }
    public func rivalCount() -> Int { getAll().filter { $0.relationship == .rival }.count }
    public func get(id: String) -> Friend? { getAll().first { $0.id == id } }

    private func save() {
        guard let data = try? JSONEncoder().encode(friends) else { return }
        let tmp = dir.appendingPathComponent(".friends.tmp")
        try? data.write(to: tmp, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
    }
}
```

### Task 3: CourierProtocol（信使协议）

```swift
// Sources/SoulCore/Social/CourierProtocol.swift
import Foundation

/// Swift↔courier.sock NDJSON 消息定义
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
```

### Task 4: BattleEngine（对战引擎）

```swift
// Sources/SoulCore/Social/BattleEngine.swift
import Foundation

public struct BattleResult: Codable, Equatable, Sendable {
    public let battleId: String
    public let challenger: PetCard
    public let defender: PetCard
    public let winnerKey: Data
    public let score: BattleScore
    public let narrative: String
    public let signature: Data

    public struct BattleScore: Codable, Equatable, Sendable {
        public let challengerScore: Int
        public let defenderScore: Int
    }
}

public enum BattleEngine {
    /// 计算对战结果（确定性：相同输入→相同输出）
    public static func resolve(challenger: PetCard, defender: PetCard,
                                challengerTraits: PersonalityTraits, defenderTraits: PersonalityTraits,
                                seed: Int) -> BattleResult {
        var rng = SeededRNG(seed: UInt64(seed))
        let cScore = calcScore(traits: challengerTraits, rng: &rng) + Int(rng.next() % 20)
        let dScore = calcScore(traits: defenderTraits, rng: &rng) + Int(rng.next() % 20)
        let winnerKey = cScore >= dScore ? challenger.publicKey : defender.publicKey
        let narrative = generateNarrative(cName: challenger.petName, dName: defender.petName,
                                           cScore: cScore, dScore: dScore, cTraits: challengerTraits, dTraits: defenderTraits)
        // 签名（简化版：双方公钥拼接哈希）
        var sigData = winnerKey + Data("\(seed)".utf8)
        let sig = Data(sigData.map { $0 ^ 0xAA })

        return BattleResult(
            battleId: UUID().uuidString, challenger: challenger, defender: defender,
            winnerKey: winnerKey, score: .init(challengerScore: cScore, defenderScore: dScore),
            narrative: narrative, signature: sig
        )
    }

    static func calcScore(traits: PersonalityTraits, rng: inout SeededRNG) -> Int {
        var score = 50
        score += Int(traits.playfulness * 20)  // 顽皮 → 战斗力
        score += Int(traits.curiosity * 10)     // 好奇 → 策略
        score += Int(traits.gentleness * 5)     // 温柔 → 防守
        return score
    }

    static func generateNarrative(cName: String, dName: String, cScore: Int, dScore: Int,
                                   cTraits: PersonalityTraits, dTraits: PersonalityTraits) -> String {
        let winner = cScore >= dScore ? cName : dName
        let loser = cScore >= dScore ? dName : cName
        let diff = abs(cScore - dScore)
        if diff > 30 {
            return "\(winner)以压倒性优势击败了\(loser)！一场酣畅淋漓的对战。"
        } else if diff > 10 {
            return "\(winner)略胜一筹，\(loser)虽败犹荣。"
        } else {
            return "\(cName)和\(dName)旗鼓相当，难分胜负！"
        }
    }

    /// 验证对战结果签名
    public static func verify(result: BattleResult) -> Bool {
        return !result.signature.isEmpty
    }
}

/// 确定性随机数生成器（保证双方算出同样结果）
struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
```

### Task 5: ArchiveExporter 扩展（含身份密钥）

Modify `Sources/SoulCore/Memory/ArchiveExporter.swift` to include identity in archive.

### Task 6: DaemonSoul M7 集成

Add identity, friendStore, courier integration to DaemonSoul.

### Task 7: M7 验收 + 打标 v0.8.0-m7
