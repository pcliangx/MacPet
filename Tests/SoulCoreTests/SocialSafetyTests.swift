import XCTest
@testable import SoulCore

final class SocialSafetyTests: XCTestCase {
    func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true); return u
    }
    func testBlockUnblock() {
        let s = SocialSafety(directory: tempDir())
        s.block(nodeId: "bad-node")
        XCTAssertTrue(s.isBlocked(nodeId: "bad-node"))
        s.unblock(nodeId: "bad-node")
        XCTAssertFalse(s.isBlocked(nodeId: "bad-node"))
    }
    func testReport() {
        let s = SocialSafety(directory: tempDir())
        s.report(nodeId: "spam-node", reason: "刷屏")
        XCTAssertEqual(s.reportCount, 1)
    }
    func testFriendsOnlyMode() {
        let s = SocialSafety(directory: tempDir())
        s.friendsOnlyMode = true
        XCTAssertFalse(s.allowsInteraction(nodeId: "stranger", isFriend: false))
        XCTAssertTrue(s.allowsInteraction(nodeId: "buddy", isFriend: true))
    }
    func testSocialMasterSwitch() {
        let s = SocialSafety(directory: tempDir())
        s.socialEnabled = false
        XCTAssertFalse(s.allowsInteraction(nodeId: "anyone", isFriend: true))
    }
    func testBlockedNodeNotAllowed() {
        let s = SocialSafety(directory: tempDir())
        s.block(nodeId: "bad")
        XCTAssertFalse(s.allowsInteraction(nodeId: "bad", isFriend: true))
    }
    func testPersistence() {
        let dir = tempDir()
        let s1 = SocialSafety(directory: dir)
        s1.block(nodeId: "persistent-block")
        let s2 = SocialSafety(directory: dir)
        XCTAssertTrue(s2.isBlocked(nodeId: "persistent-block"))
    }
}
