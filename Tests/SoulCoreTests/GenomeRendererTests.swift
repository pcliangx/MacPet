import XCTest
@testable import SoulCore

final class GenomeRendererTests: XCTestCase {
    func testRenderProducesValidHTML() {
        let html = GenomeRenderer.render(genome: .default, stage: .baby, state: "idle")
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("state-idle"))
        XCTAssertTrue(html.contains("pet-root"))
    }
    func testRenderDifferentStates() {
        for state in ["idle", "happy", "sleepy", "missyou", "sleeping", "alert"] {
            let html = GenomeRenderer.render(genome: .default, stage: .baby, state: state)
            XCTAssertTrue(html.contains("state-\(state)"))
        }
    }
    func testStageScaleVaries() {
        XCTAssertTrue(GenomeRenderer.stageScale(.egg) < GenomeRenderer.stageScale(.baby))
        XCTAssertTrue(GenomeRenderer.stageScale(.baby) < GenomeRenderer.stageScale(.juvenile))
        XCTAssertTrue(GenomeRenderer.stageScale(.juvenile) < GenomeRenderer.stageScale(.adult))
    }
    func testGenomeAffectsSVG() {
        let orange = GenomeRenderer.render(genome: .default, stage: .baby)
        var blue = AppearanceGenome.default; blue.furHue = 220
        let blueHTML = GenomeRenderer.render(genome: blue, stage: .baby)
        XCTAssertTrue(orange.contains("hsl(28"))
        XCTAssertTrue(blueHTML.contains("hsl(220"))
    }
    func testBlushToggle() {
        var noBlush = AppearanceGenome.default; noBlush.blushEnabled = false
        let html = GenomeRenderer.render(genome: noBlush, stage: .baby)
        XCTAssertFalse(html.contains("#FF9FAC"))
    }
    func testAllEarShapesRender() {
        for ear in AppearanceGenome.EarShape.allCases {
            var g = AppearanceGenome.default; g.earShape = ear
            let html = GenomeRenderer.render(genome: g, stage: .baby)
            XCTAssertFalse(html.isEmpty)
        }
    }
    func testAllTailTypesRender() {
        for tail in AppearanceGenome.TailType.allCases {
            var g = AppearanceGenome.default; g.tailType = tail
            let html = GenomeRenderer.render(genome: g, stage: .baby)
            XCTAssertFalse(html.isEmpty)
        }
    }
}
