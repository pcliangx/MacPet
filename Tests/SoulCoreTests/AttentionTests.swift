import XCTest
@testable import SoulCore

final class AttentionTests: XCTestCase {
    let watched: Set<String> = ["com.apple.Terminal", "com.googlecode.iterm2"]
    func testIdleMeansAway() {
        let s = PresenceSnapshot(frontmostBundleID: "com.apple.Terminal", idleSeconds: 300, watchedBundleIDs: watched)
        XCTAssertEqual(AttentionResolver.resolve(s), .away)
    }
    func testWatchedFrontmostMeansAttending() {
        let s = PresenceSnapshot(frontmostBundleID: "com.googlecode.iterm2", idleSeconds: 5, watchedBundleIDs: watched)
        XCTAssertEqual(AttentionResolver.resolve(s), .attending)
    }
    func testOtherwiseElsewhere() {
        let s = PresenceSnapshot(frontmostBundleID: "com.apple.Safari", idleSeconds: 5, watchedBundleIDs: watched)
        XCTAssertEqual(AttentionResolver.resolve(s), .elsewhere)
    }
}
