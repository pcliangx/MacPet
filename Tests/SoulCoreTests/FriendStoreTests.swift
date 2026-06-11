import XCTest
@testable import SoulCore

final class FriendStoreTests: XCTestCase {
    func tempDir() -> URL { let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true); return u }
    func testAddFriend() {
        let store = FriendStore(directory: tempDir())
        let id = PetIdentity.generate(petName: "朋友", species: "小猫")
        let ticket = FriendTicket.create(from: id)
        store.addFriend(from: ticket)
        XCTAssertEqual(store.friendCount(), 1)
    }
    func testNoDuplicateFriends() {
        let store = FriendStore(directory: tempDir())
        let id = PetIdentity.generate(petName: "friend", species: "test")
        let ticket = FriendTicket.create(from: id)
        store.addFriend(from: ticket); store.addFriend(from: ticket)
        XCTAssertEqual(store.friendCount(), 1)
    }
    func testSetRival() {
        let store = FriendStore(directory: tempDir())
        let id = PetIdentity.generate(petName: "rival", species: "test")
        let friend = store.addFriend(from: FriendTicket.create(from: id))
        store.setRival(id: friend.id)
        XCTAssertEqual(store.rivalCount(), 1)
    }
    func testUpdateBattle() {
        let store = FriendStore(directory: tempDir())
        let id = PetIdentity.generate(petName: "test", species: "test")
        let friend = store.addFriend(from: FriendTicket.create(from: id))
        store.updateBattle(id: friend.id, won: true)
        XCTAssertEqual(store.get(id: friend.id)?.battleRecord.wins, 1)
    }
    func testPersistence() {
        let dir = tempDir(); let s1 = FriendStore(directory: dir)
        let id = PetIdentity.generate(petName: "test", species: "test")
        s1.addFriend(from: FriendTicket.create(from: id))
        let s2 = FriendStore(directory: dir); XCTAssertEqual(s2.friendCount(), 1)
    }
}
