import XCTest
@testable import SoulCore

final class CourierProtocolTests: XCTestCase {
    func testHelloRoundTrip() throws {
        let msg = CourierMessage.hello(nodeId: "abc123")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(CourierMessage.self, from: data)
        XCTAssertEqual(decoded, msg)
    }
    func testBattleChallengeRoundTrip() throws {
        let card = PetCard(publicKey: Data([1,2,3]), petName: "泡沫", species: "狐狸")
        let msg = CourierMessage.battleChallenge(from: card, battleId: "b1", seed: 42)
        let decoded = try JSONDecoder().decode(CourierMessage.self, from: JSONEncoder().encode(msg))
        XCTAssertEqual(decoded, msg)
    }
    func testAnnounceRoundTrip() throws {
        let card = PetCard(publicKey: Data([4,5,6]), petName: "test", species: "test")
        let msg = CourierMessage.announcePresence(card: card)
        let decoded = try JSONDecoder().decode(CourierMessage.self, from: JSONEncoder().encode(msg))
        XCTAssertEqual(decoded, msg)
    }
    func testUnknownTypeFallback() throws {
        let json = #"{"t":"unknown.type","x":1}"#
        let msg = try JSONDecoder().decode(CourierMessage.self, from: Data(json.utf8))
        if case .hello(let n) = msg { XCTAssertEqual(n, "unknown") } else { XCTFail() }
    }
}
