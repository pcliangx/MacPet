import XCTest
@testable import SoulCore

final class BadgeCollectionTests: XCTestCase {
    func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true); return u
    }
    func testFirstFriendBadge() {
        let store = BadgeCollectionStore(directory: tempDir())
        let new = store.checkUnlocks(friendCount: 1, rivalCount: 0, totalWins: 0, sightingCount: 0)
        XCTAssertTrue(new.contains { $0.id == "first-friend" })
    }
    func testNoDuplicateUnlocks() {
        let store = BadgeCollectionStore(directory: tempDir())
        _ = store.checkUnlocks(friendCount: 1, rivalCount: 0, totalWins: 0, sightingCount: 0)
        let second = store.checkUnlocks(friendCount: 1, rivalCount: 0, totalWins: 0, sightingCount: 0)
        XCTAssertTrue(second.isEmpty)
    }
    func testTenWinsBadge() {
        let store = BadgeCollectionStore(directory: tempDir())
        let new = store.checkUnlocks(friendCount: 0, rivalCount: 0, totalWins: 10, sightingCount: 0)
        XCTAssertTrue(new.contains { $0.id == "ten-wins" })
        XCTAssertTrue(new.contains { $0.id == "first-win" })  // 同时解锁首胜
    }
    func testCollectionShowsAll() {
        let store = BadgeCollectionStore(directory: tempDir())
        XCTAssertEqual(store.collection().count, Badge.allBadges.count)
    }
    func testPersistence() {
        let dir = tempDir()
        let s1 = BadgeCollectionStore(directory: dir)
        _ = s1.checkUnlocks(friendCount: 1, rivalCount: 0, totalWins: 0, sightingCount: 0)
        let s2 = BadgeCollectionStore(directory: dir)
        XCTAssertTrue(s2.isUnlocked("first-friend"))
    }
}
