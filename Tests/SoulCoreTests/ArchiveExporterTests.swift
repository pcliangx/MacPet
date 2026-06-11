import XCTest
@testable import SoulCore

final class ArchiveExporterTests: XCTestCase {
    func testExportImportRoundTrip() throws {
        let memories = [Memory(kind: .episodic, content: "test memory")]
        var growth = GrowthState(); growth.totalXP = 500
        let data = try ArchiveExporter.export(memories: memories, growth: growth, soul: SoulState())
        let archive = try ArchiveExporter.importArchive(data)
        XCTAssertEqual(archive.memories.count, 1)
        XCTAssertEqual(archive.growthState.totalXP, 500)
        XCTAssertEqual(archive.version, 1)
    }
    func testExportedJSONIsPrettyPrinted() throws {
        let data = try ArchiveExporter.export(memories: [], growth: GrowthState(), soul: SoulState())
        let str = String(data: data, encoding: .utf8)!
        XCTAssertTrue(str.contains("\n"))  // pretty printed
    }
    func testImportRejectsInvalidData() {
        XCTAssertThrowsError(try ArchiveExporter.importArchive(Data("bad".utf8)))
    }
}
