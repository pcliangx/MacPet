import XCTest
@testable import SoulCore

final class StateStoreTests: XCTestCase {
    func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    func testSaveLoadRoundTrip() throws {
        let store = StateStore(directory: tempDir(), clock: TestClock(Date(timeIntervalSince1970: 0)))
        var s = SoulState(); s.mood = .happy; s.queuedThoughts = ["想给主人看个东西"]
        try store.save(s)
        XCTAssertEqual(store.load(), s)
    }
    func testCorruptFileFallsBackToDefaultAndPreservesEvidence() throws {
        let dir = tempDir()
        let store = StateStore(directory: dir, clock: TestClock(Date(timeIntervalSince1970: 0)))
        try Data("not json".utf8).write(to: dir.appendingPathComponent("soul-state.json"))
        XCTAssertEqual(store.load(), SoulState())
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(names.contains { $0.hasPrefix("soul-state.corrupt") })
    }
    func testDailyBackupRotationKeepsSeven() throws {
        let dir = tempDir()
        let clock = TestClock(ISO8601DateFormatter().date(from: "2026-06-01T12:00:00+08:00")!)
        let store = StateStore(directory: dir, clock: clock)
        for _ in 0..<10 { try store.save(SoulState()); clock.advance(by: 86_400) }
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("backups").path)
        XCTAssertEqual(backups.count, 7)
    }
}
