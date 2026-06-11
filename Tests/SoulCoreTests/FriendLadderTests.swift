import XCTest
@testable import SoulCore

final class FriendLadderTests: XCTestCase {
    func makeFriend(name: String, myWins: Int, myLosses: Int) -> Friend {
        Friend(id: name, card: PetCard(publicKey: Data(name.utf8), petName: name, species: "t"),
               relationship: .friend, addedAt: Date(), lastSeen: nil,
               battleRecord: .init(wins: myWins, losses: myLosses, draws: 0))
    }
    func testRankingSortsByScore() {
        // friendA: 我3胜0负 → 它0胜3负（弱）; friendB: 我0胜3负 → 它3胜0负（强）
        let friends = [makeFriend(name: "A", myWins: 3, myLosses: 0),
                       makeFriend(name: "B", myWins: 0, myLosses: 3)]
        let ranking = FriendLadder.ranking(friends: friends)
        XCTAssertEqual(ranking.first?.petName, "B")  // B 它赢得多 → 排第一
    }
    func testIncludeSelf() {
        let friends = [makeFriend(name: "A", myWins: 0, myLosses: 0)]
        let ranking = FriendLadder.ranking(friends: friends, includeSelf: (name: "我", wins: 5, losses: 0))
        XCTAssertEqual(ranking.first?.petName, "我")
    }
    func testMoreGamesBeatsFewGames() {
        // 同 100% 胜率，10 场 > 1 场
        let s10 = FriendLadder.score(wins: 10, losses: 0)
        let s1 = FriendLadder.score(wins: 1, losses: 0)
        XCTAssertTrue(s10 > s1)
    }
    func testZeroGamesZeroScore() {
        XCTAssertEqual(FriendLadder.score(wins: 0, losses: 0), 0)
    }
    func testAdultGating() {
        XCTAssertFalse(FriendLadder.isUnlocked(stage: .juvenile))
        XCTAssertTrue(FriendLadder.isUnlocked(stage: .adult))
    }
}
