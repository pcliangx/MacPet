import XCTest
@testable import SoulCore

final class ClawAuthManagerTests: XCTestCase {
    func testAuthorizeFreeHome() {
        let tool = ToolSpec(name: "test", description: "", parametersJSON: "{}", minStage: .baby)
        XCTAssertTrue(ClawAuthManager.authorize(tool: tool, currentStage: .baby, requestTier: .freeHome))
    }

    func testAuthorizeStageGate() {
        let tool = ToolSpec(name: "test", description: "", parametersJSON: "{}", minStage: .juvenile)
        XCTAssertFalse(ClawAuthManager.authorize(tool: tool, currentStage: .baby, requestTier: .freeHome))
        XCTAssertTrue(ClawAuthManager.authorize(tool: tool, currentStage: .juvenile, requestTier: .freeHome))
    }

    func testNeverTierBlocked() {
        let tool = ToolSpec(name: "test", description: "", parametersJSON: "{}", minStage: .baby)
        XCTAssertFalse(ClawAuthManager.authorize(tool: tool, currentStage: .adult, requestTier: .never))
    }

    func testPluginAuthRestrictions() {
        XCTAssertTrue(ClawAuthManager.authorizePlugin(toolTier: .freeRead))
        XCTAssertTrue(ClawAuthManager.authorizePlugin(toolTier: .ask))
        XCTAssertFalse(ClawAuthManager.authorizePlugin(toolTier: .freeHome))
        XCTAssertFalse(ClawAuthManager.authorizePlugin(toolTier: .never))
    }

    func testPathAccess() {
        XCTAssertTrue(ClawAuthManager.canAccess(path: "/home/pet/diary.md", tier: .freeHome, petHomeDir: "/home/pet"))
        XCTAssertFalse(ClawAuthManager.canAccess(path: "/etc/passwd", tier: .freeHome, petHomeDir: "/home/pet"))
        XCTAssertTrue(ClawAuthManager.canAccess(path: "/etc/passwd", tier: .freeRead, petHomeDir: "/home/pet"))
    }
}
