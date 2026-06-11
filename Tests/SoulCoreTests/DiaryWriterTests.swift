import XCTest
@testable import SoulCore

final class DiaryWriterTests: XCTestCase {
    func testBabyDiaryTone() {
        let entry = DiaryWriter.writeEntry(date: Date(), events: [], mood: .happy, stage: .baby)
        XCTAssertTrue(entry.contains("嗯"))
    }
    func testJuvenileDiaryTone() {
        let entry = DiaryWriter.writeEntry(date: Date(), events: [], mood: .calm, stage: .juvenile)
        XCTAssertTrue(entry.contains("有意思"))
    }
    func testIncludesEvents() {
        let events = [Memory(kind: .episodic, content: "和主人聊天了")]
        let entry = DiaryWriter.writeEntry(date: Date(), events: events, mood: .happy, stage: .juvenile)
        XCTAssertTrue(entry.contains("和主人聊天了"))
    }
    func testIncludesMood() {
        let entry = DiaryWriter.writeEntry(date: Date(), events: [], mood: .sleepy, stage: .adult)
        XCTAssertTrue(entry.contains("犯困"))
    }
    func testSaveCreatesFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try DiaryWriter.save(entry: "test diary", date: Date(), to: dir)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files[0].hasSuffix(".md"))
    }
}
