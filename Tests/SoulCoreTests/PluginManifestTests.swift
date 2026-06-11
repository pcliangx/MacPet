import XCTest
@testable import SoulCore

final class PluginManifestTests: XCTestCase {
    let validJSON = """
    {"name":"weather","displayName":"天气感知","version":"0.1.0","kind":["sense","tool"],
     "entry":{"type":"exec","cmd":"./weather"},
     "permissions":["network"],
     "tools":[{"name":"now","tier":"free-read"}],
     "senses":[{"id":"weather.changed","priority":"ambient","dailyBudget":8}],
     "persona_hints":{"toyName":"气象风向标","intro":"能闻出今天会不会下雨"}}
    """
    func testParseValid() throws {
        let m = try PluginManifest.parse(Data(validJSON.utf8))
        XCTAssertEqual(m.name, "weather")
        XCTAssertEqual(m.entry.type, "exec")
        XCTAssertEqual(m.tools.count, 1)
        XCTAssertEqual(m.personaHints?.toyName, "气象风向标")
    }
    func testValidateOK() throws {
        let m = try PluginManifest.parse(Data(validJSON.utf8))
        XCTAssertTrue(m.validate().isEmpty)
    }
    func testValidateRejectsNeverTier() throws {
        let bad = validJSON.replacingOccurrences(of: "\"free-read\"", with: "\"never\"")
        let m = try PluginManifest.parse(Data(bad.utf8))
        XCTAssertFalse(m.validate().isEmpty)
    }
    func testValidateRejectsFreeHomeTier() throws {
        let bad = validJSON.replacingOccurrences(of: "\"free-read\"", with: "\"free-home\"")
        let m = try PluginManifest.parse(Data(bad.utf8))
        XCTAssertFalse(m.validate().isEmpty)
    }
    func testValidateRejectsBadEntryType() throws {
        let bad = validJSON.replacingOccurrences(of: "\"exec\"", with: "\"binary\"")
        let m = try PluginManifest.parse(Data(bad.utf8))
        XCTAssertFalse(m.validate().isEmpty)
    }
    func testToToolSpecsNamespaced() throws {
        let m = try PluginManifest.parse(Data(validJSON.utf8))
        let specs = m.toToolSpecs()
        XCTAssertEqual(specs.first?.name, "weather.now")
        XCTAssertEqual(specs.first?.tier, .freeRead)
        XCTAssertEqual(specs.first?.minStage, .juvenile)
    }
    func testParseRejectsGarbage() {
        XCTAssertThrowsError(try PluginManifest.parse(Data("not json".utf8)))
    }
}
