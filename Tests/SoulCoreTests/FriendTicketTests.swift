import XCTest
@testable import SoulCore

final class FriendTicketTests: XCTestCase {
    func testCreateTicket() {
        let id = PetIdentity.generate(petName: "泡沫", species: "小狐狸")
        let ticket = FriendTicket.create(from: id)
        XCTAssertEqual(ticket.fromCard.petName, "泡沫")
    }
    func testEncodeDecodeRoundTrip() {
        let id = PetIdentity.generate(petName: "test", species: "test")
        let ticket = FriendTicket.create(from: id)
        let encoded = ticket.encode()
        let decoded = FriendTicket.decode(encoded)
        XCTAssertEqual(decoded, ticket)
    }
    func testIsValid() {
        let id = PetIdentity.generate(petName: "test", species: "test")
        let ticket = FriendTicket.create(from: id)
        XCTAssertTrue(ticket.isValid())
    }
    func testDecodeInvalidReturnsNil() {
        XCTAssertNil(FriendTicket.decode("not-base64!!!"))
    }
}
