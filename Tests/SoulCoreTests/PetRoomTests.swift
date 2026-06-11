import XCTest
@testable import SoulCore

final class PetRoomTests: XCTestCase {
    func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    func testAddItem() {
        let s = PetRoomStore(directory: tempDir())
        s.addItem(name: "小画", description: "画了一幅画")
        XCTAssertEqual(s.itemCount, 1)
    }

    func testAddGift() {
        let s = PetRoomStore(directory: tempDir())
        s.addGift(description: "一朵小花", forOwner: true)
        XCTAssertEqual(s.giftCount, 1)
    }

    func testPersistence() {
        let dir = tempDir()
        let s1 = PetRoomStore(directory: dir)
        s1.addItem(name: "test", description: "test")
        let s2 = PetRoomStore(directory: dir)
        XCTAssertEqual(s2.itemCount, 1)
    }

    func testEmptyRoom() {
        XCTAssertEqual(PetRoomStore(directory: tempDir()).itemCount, 0)
    }
}
