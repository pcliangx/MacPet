import XCTest
@testable import SoulCore

final class PersonaSynthTests: XCTestCase {
    let genome = Genome(petName: "泡沫", species: "圆滚滚的橘色小狐狸", furHue: 28,
                        basePersona: "好奇、黏人、有点小得意")
    func testBabyPromptEnforcesBabyTalk() {
        let p = PersonaSynth.systemPrompt(genome: genome, stage: .baby, mood: .happy,
                                          hour: 15, ownerPresent: true)
        XCTAssertTrue(p.contains("泡沫"))
        XCTAssertTrue(p.contains("奶声短句"))
        XCTAssertTrue(p.contains("speak"))
        XCTAssertTrue(p.contains("开心"))
    }
    func testMissingMoodColorsPrompt() {
        let p = PersonaSynth.systemPrompt(genome: genome, stage: .baby, mood: .missing,
                                          hour: 23, ownerPresent: false)
        XCTAssertTrue(p.contains("想你"))
        XCTAssertTrue(p.contains("不在"))
    }
}
