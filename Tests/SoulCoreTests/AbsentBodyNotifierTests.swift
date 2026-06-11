import XCTest
@testable import SoulCore

final class AbsentBodyNotifierTests: XCTestCase {
    func testBuildsOsascriptCommand() {
        let cmd = AbsentBodyNotifier.buildCommand(title: "CC 等你", body: "需要你批准")
        XCTAssertTrue(cmd.contains("display notification"))
        XCTAssertTrue(cmd.contains("CC 等你"))
        XCTAssertTrue(cmd.contains("需要你批准"))
    }
    func testShouldNotifyOnlyForAlertsWhenBodyAbsent() {
        XCTAssertTrue(AbsentBodyNotifier.shouldNotify(priority: .alert, bodyConnected: false))
        XCTAssertFalse(AbsentBodyNotifier.shouldNotify(priority: .nudge, bodyConnected: false))
        XCTAssertFalse(AbsentBodyNotifier.shouldNotify(priority: .ambient, bodyConnected: false))
        XCTAssertFalse(AbsentBodyNotifier.shouldNotify(priority: .alert, bodyConnected: true))
    }
    func testEscapesQuotes() {
        let cmd = AbsentBodyNotifier.buildCommand(title: "It's", body: "say \"hi\"")
        XCTAssertTrue(cmd.contains("\\\""))
    }
}
