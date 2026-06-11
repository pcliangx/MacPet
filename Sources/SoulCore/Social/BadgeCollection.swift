import Foundation

/// M8 徽章图鉴（spec §9.4）：本地颁发，不进成长经济。
public struct Badge: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public var unlockedAt: Date?

    public static let allBadges: [Badge] = [
        Badge(id: "first-friend", name: "第一个朋友", description: "添加了第一个好友", unlockedAt: nil),
        Badge(id: "first-win", name: "首胜", description: "赢得第一场对战", unlockedAt: nil),
        Badge(id: "ten-wins", name: "十连胜者", description: "累计赢得 10 场对战", unlockedAt: nil),
        Badge(id: "first-rival", name: "结下宿敌", description: "有了第一个宿敌", unlockedAt: nil),
        Badge(id: "plaza-regular", name: "广场常客", description: "广场见闻达到 20 条", unlockedAt: nil),
        Badge(id: "social-butterfly", name: "社交花蝴蝶", description: "好友数达到 5 个", unlockedAt: nil),
    ]
}

public final class BadgeCollectionStore: @unchecked Sendable {
    private let dir: URL
    private let lock = NSLock()
    private var unlocked: [String: Date] = [:]   // badgeId → unlock date
    private var fileURL: URL { dir.appendingPathComponent("badges.json") }

    public init(directory: URL) {
        self.dir = directory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: fileURL),
           let u = try? JSONDecoder().decode([String: Date].self, from: data) { unlocked = u }
    }

    /// 检查并解锁新徽章。返回本次新解锁的徽章。
    public func checkUnlocks(friendCount: Int, rivalCount: Int, totalWins: Int, sightingCount: Int) -> [Badge] {
        lock.lock(); defer { lock.unlock() }
        var newBadges: [Badge] = []
        func unlock(_ id: String) {
            guard unlocked[id] == nil else { return }
            unlocked[id] = Date()
            if var badge = Badge.allBadges.first(where: { $0.id == id }) {
                badge.unlockedAt = unlocked[id]
                newBadges.append(badge)
            }
        }
        if friendCount >= 1 { unlock("first-friend") }
        if friendCount >= 5 { unlock("social-butterfly") }
        if totalWins >= 1 { unlock("first-win") }
        if totalWins >= 10 { unlock("ten-wins") }
        if rivalCount >= 1 { unlock("first-rival") }
        if sightingCount >= 20 { unlock("plaza-regular") }
        if !newBadges.isEmpty { save() }
        return newBadges
    }

    public func isUnlocked(_ id: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return unlocked[id] != nil
    }

    public var unlockedCount: Int { lock.lock(); defer { lock.unlock() }; return unlocked.count }

    /// 全图鉴（含锁定状态）
    public func collection() -> [Badge] {
        lock.lock(); defer { lock.unlock() }
        return Badge.allBadges.map { badge in
            var b = badge; b.unlockedAt = unlocked[badge.id]; return b
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(unlocked) else { return }
        let tmp = dir.appendingPathComponent(".badges.tmp")
        try? data.write(to: tmp, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
    }
}
