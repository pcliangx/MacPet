import XCTest
@testable import SoulCore

final class PetProjectTests: XCTestCase {
    func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    func testAddProject() {
        let s = PetProjectStore(directory: tempDir())
        s.add(PetProject(name: "收集石头", description: "收集各种好看的石头"))
        XCTAssertEqual(s.activeCount(), 1)
    }

    func testUpdateProgress() {
        let s = PetProjectStore(directory: tempDir())
        let p = PetProject(name: "test", description: "")
        s.add(p)
        s.updateProgress(id: p.id, progress: 0.5)
        XCTAssertEqual(s.getAll().first?.progress, 0.5)
    }

    func testAutoComplete() {
        let s = PetProjectStore(directory: tempDir())
        let p = PetProject(name: "test", description: "")
        s.add(p)
        s.updateProgress(id: p.id, progress: 1.0)
        XCTAssertEqual(s.getAll().first?.status, .completed)
    }

    func testProgressClamped() {
        let s = PetProjectStore(directory: tempDir())
        let p = PetProject(name: "test", description: "")
        s.add(p)
        s.updateProgress(id: p.id, progress: 2.0)
        XCTAssertEqual(s.getAll().first?.progress, 1.0)
    }

    func testPersistence() {
        let dir = tempDir()
        let s1 = PetProjectStore(directory: dir)
        s1.add(PetProject(name: "test", description: ""))
        let s2 = PetProjectStore(directory: dir)
        XCTAssertEqual(s2.activeCount(), 1)
    }
}
