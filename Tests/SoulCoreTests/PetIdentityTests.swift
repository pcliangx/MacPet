import XCTest
@testable import SoulCore

final class PetIdentityTests: XCTestCase {
    func testGenerateIdentity() {
        let id = PetIdentity.generate(petName: "泡沫", species: "小狐狸")
        XCTAssertEqual(id.petName, "泡沫"); XCTAssertEqual(id.publicKey.count, 32)
        XCTAssertEqual(id.privateKey.count, 64)
    }
    func testCard() {
        let id = PetIdentity.generate(petName: "泡沫", species: "小狐狸")
        let card = id.card()
        XCTAssertEqual(card.petName, "泡沫"); XCTAssertEqual(card.publicKey, id.publicKey)
    }
    func testSign() {
        let id = PetIdentity.generate(petName: "test", species: "test")
        let sig = id.sign(Data("hello".utf8))
        XCTAssertFalse(sig.isEmpty)
    }
    func testCodableRoundTrip() throws {
        let id = PetIdentity.generate(petName: "test", species: "test")
        let decoded = try JSONDecoder().decode(PetIdentity.self, from: JSONEncoder().encode(id))
        XCTAssertEqual(decoded.publicKey, id.publicKey)
    }
    func testUniqueKeys() {
        let a = PetIdentity.generate(petName: "a", species: "a")
        let b = PetIdentity.generate(petName: "b", species: "b")
        XCTAssertNotEqual(a.publicKey, b.publicKey)
    }
}
