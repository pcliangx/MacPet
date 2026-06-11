import Foundation

public struct Friend: Codable, Equatable, Sendable, Identifiable {
    public let id: String; public var card: PetCard; public var relationship: Relationship
    public var addedAt: Date; public var lastSeen: Date?; public var battleRecord: BattleRecord
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
        if let data = try? Data(contentsOf: fileURL), let f = try? JSONDecoder().decode([Friend].self, from: data) { friends = f }
    }
    public func addFriend(from ticket: FriendTicket) -> Friend {
        lock.lock(); defer { lock.unlock() }
        let id = ticket.fromCard.publicKey.base64EncodedString()
        if let existing = friends.first(where: { $0.id == id }) { return existing }
        let friend = Friend(id: id, card: ticket.fromCard, relationship: .friend, addedAt: Date(), lastSeen: nil, battleRecord: .init())
        friends.append(friend); save(); return friend
    }
    public func setRival(id: String) { lock.lock(); defer { lock.unlock() }; guard let idx = friends.firstIndex(where: { $0.id == id }) else { return }; friends[idx].relationship = .rival; save() }
    public func updateLastSeen(id: String) { lock.lock(); defer { lock.unlock() }; guard let idx = friends.firstIndex(where: { $0.id == id }) else { return }; friends[idx].lastSeen = Date(); save() }
    public func updateBattle(id: String, won: Bool) { lock.lock(); defer { lock.unlock() }; guard let idx = friends.firstIndex(where: { $0.id == id }) else { return }; if won { friends[idx].battleRecord.wins += 1 } else { friends[idx].battleRecord.losses += 1 }; save() }
    public func getAll() -> [Friend] { lock.lock(); defer { lock.unlock() }; return friends }
    public func friendCount() -> Int { getAll().filter { $0.relationship == .friend }.count }
    public func rivalCount() -> Int { getAll().filter { $0.relationship == .rival }.count }
    public func get(id: String) -> Friend? { getAll().first { $0.id == id } }
    private func save() {
        guard let data = try? JSONEncoder().encode(friends) else { return }
        let tmp = dir.appendingPathComponent(".friends.tmp")
        try? data.write(to: tmp, options: .atomic); _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
    }
}
