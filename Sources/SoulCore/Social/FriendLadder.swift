import Foundation

/// M8 朋友圈天梯（spec §9.4）：从签名战报本地计算的小圈子排名。成年解锁。
public enum FriendLadder {
    public struct Entry: Equatable, Sendable, Identifiable {
        public let id: String
        public let petName: String
        public let wins: Int
        public let losses: Int
        public let score: Double   // 排名分
    }

    /// 计算天梯（胜率 × log(场次+1) 加权——少打高胜率不该霸榜）
    public static func ranking(friends: [Friend], includeSelf: (name: String, wins: Int, losses: Int)? = nil) -> [Entry] {
        var entries: [Entry] = friends.map { f in
            Entry(id: f.id, petName: f.card.petName,
                  wins: f.battleRecord.losses,   // 注意：friend 的 battleRecord 是「我对它」的战绩，反转即它的战绩
                  losses: f.battleRecord.wins,
                  score: score(wins: f.battleRecord.losses, losses: f.battleRecord.wins))
        }
        if let me = includeSelf {
            entries.append(Entry(id: "self", petName: me.name, wins: me.wins, losses: me.losses,
                                  score: score(wins: me.wins, losses: me.losses)))
        }
        return entries.sorted { $0.score > $1.score }
    }

    static func score(wins: Int, losses: Int) -> Double {
        let total = wins + losses
        guard total > 0 else { return 0 }
        let winRate = Double(wins) / Double(total)
        return winRate * log(Double(total) + 1) * 100
    }

    /// 阶段门控：成年解锁
    public static func isUnlocked(stage: Stage) -> Bool { stage >= .adult }
}
