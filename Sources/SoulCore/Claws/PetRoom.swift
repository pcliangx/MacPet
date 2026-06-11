import Foundation

public struct PetRoom: Codable, Equatable, Sendable {
    public var items: [RoomItem] = []
    public var gifts: [Gift] = []

    public struct RoomItem: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public var name: String
        public var description: String
        public var createdAt: Date
    }

    public struct Gift: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public var description: String
        public var forOwner: Bool
        public var createdAt: Date
    }
}

public final class PetRoomStore: @unchecked Sendable {
    private let dir: URL
    private let lock = NSLock()
    private var room: PetRoom

    private var fileURL: URL { dir.appendingPathComponent("pet-room.json") }

    public init(directory: URL) {
        self.dir = directory
        self.room = PetRoom()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: fileURL),
           let r = try? JSONDecoder().decode(PetRoom.self, from: data) {
            room = r
        }
    }

    public func addItem(name: String, description: String) -> PetRoom.RoomItem {
        lock.lock(); defer { lock.unlock() }
        let item = PetRoom.RoomItem(
            id: UUID().uuidString, name: name, description: description, createdAt: Date()
        )
        room.items.append(item)
        save()
        return item
    }

    public func addGift(description: String, forOwner: Bool) -> PetRoom.Gift {
        lock.lock(); defer { lock.unlock() }
        let gift = PetRoom.Gift(
            id: UUID().uuidString, description: description, forOwner: forOwner, createdAt: Date()
        )
        room.gifts.append(gift)
        save()
        return gift
    }

    public func getRoom() -> PetRoom {
        lock.lock(); defer { lock.unlock() }
        return room
    }

    public var itemCount: Int { getRoom().items.count }
    public var giftCount: Int { getRoom().gifts.count }

    private func save() {
        guard let data = try? JSONEncoder().encode(room) else { return }
        let tmp = dir.appendingPathComponent(".pet-room.tmp")
        try? data.write(to: tmp, options: .atomic)
        _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
    }
}
