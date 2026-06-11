import XCTest
@testable import SoulCore

final class GiftCeremonyTests: XCTestCase {
    func makeManifest() -> PluginManifest {
        try! PluginManifest.parse(Data("""
        {"name":"weather","displayName":"天气感知","version":"1.0","kind":["sense"],
         "entry":{"type":"exec","cmd":"./w"},
         "persona_hints":{"toyName":"气象风向标","intro":"能闻出今天会不会下雨"}}
        """.utf8))
    }
    func testCeremonyUsesToyName() {
        let c = GiftCeremony.perform(manifest: makeManifest(), petName: "泡沫")
        XCTAssertTrue(c.unwrapLine.contains("气象风向标"))
        XCTAssertEqual(c.toyNickname, "气象风向标")
    }
    func testCeremonyIncludesIntro() {
        let c = GiftCeremony.perform(manifest: makeManifest(), petName: "泡沫")
        XCTAssertTrue(c.tryOutLine.contains("闻出"))
    }
    func testDiaryNote() {
        let c = GiftCeremony.perform(manifest: makeManifest(), petName: "泡沫")
        XCTAssertTrue(c.diaryNote.contains("礼物"))
    }
    func testFallbackWithoutPersonaHints() throws {
        let m = try PluginManifest.parse(Data("""
        {"name":"plain","displayName":"普通插件","version":"1.0","kind":["tool"],
         "entry":{"type":"exec","cmd":"./p"}}
        """.utf8))
        let c = GiftCeremony.perform(manifest: m, petName: "泡沫")
        XCTAssertTrue(c.unwrapLine.contains("普通插件"))
    }
    func testPutAwayNotSad() {
        let line = GiftCeremony.putAway(toyName: "玩具")
        XCTAssertTrue(line.contains("改天再玩"))
    }
}
