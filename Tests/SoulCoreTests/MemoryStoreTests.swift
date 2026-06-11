import XCTest
@testable import SoulCore

final class MemoryStoreTests: XCTestCase {
    func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true); return u
    }
    func testAddAndGet() {
        let store = MemoryStore(directory: tempDir())
        let m = Memory(kind: .episodic, content: "test")
        store.add(m)
        XCTAssertEqual(store.count(), 1)
        XCTAssertNotNil(store.get(id: m.id))
    }
    func testDelete() {
        let store = MemoryStore(directory: tempDir())
        let m = Memory(kind: .episodic, content: "test")
        store.add(m); store.delete(id: m.id)
        XCTAssertEqual(store.count(), 0)
    }
    func testCorrect() {
        let store = MemoryStore(directory: tempDir())
        let m = Memory(kind: .semantic, content: "old", confidence: 0.8)
        store.add(m); store.correct(id: m.id, newContent: "new")
        let updated = store.get(id: m.id)!
        XCTAssertEqual(updated.content, "new")
        XCTAssertTrue(updated.confidence < 0.8)
    }
    func testPersistenceAcrossInstances() {
        let dir = tempDir()
        let store1 = MemoryStore(directory: dir)
        store1.add(Memory(kind: .episodic, content: "persisted"))
        let store2 = MemoryStore(directory: dir)
        XCTAssertEqual(store2.count(), 1)
    }
    func testCountByKind() {
        let store = MemoryStore(directory: tempDir())
        store.add(Memory(kind: .episodic, content: "a"))
        store.add(Memory(kind: .semantic, content: "b"))
        store.add(Memory(kind: .episodic, content: "c"))
        XCTAssertEqual(store.count(kind: .episodic), 2)
        XCTAssertEqual(store.count(kind: .semantic), 1)
    }
}
