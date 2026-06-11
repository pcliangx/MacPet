import XCTest
@testable import SoulCore

final class GrowthStateStoreTests: XCTestCase {
    func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true); return u
    }
    func testSaveLoadRoundTrip() throws {
        let store = GrowthStateStore(directory: tempDir(), clock: TestClock(Date(timeIntervalSince1970: 0)))
        var g = GrowthState(); g.totalXP = 1234; g.bond = 42; g.streakDays = 7
        try store.save(g)
        XCTAssertEqual(store.load(), g)
    }
    func testMissingFileReturnsDefault() {
        XCTAssertEqual(GrowthStateStore(directory: tempDir(), clock: TestClock(Date())).load().totalXP, 0)
    }
    func testCorruptFileReturnsDefault() throws {
        let dir = tempDir()
        try Data("bad".utf8).write(to: dir.appendingPathComponent("growth-state.json"))
        XCTAssertEqual(GrowthStateStore(directory: dir, clock: TestClock(Date())).load().totalXP, 0)
    }
}
