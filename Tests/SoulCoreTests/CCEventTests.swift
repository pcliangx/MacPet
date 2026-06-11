// Tests/SoulCoreTests/CCEventTests.swift
import XCTest
@testable import SoulCore

final class CCEventTests: XCTestCase {
    func testParseNotificationEvent() throws {
        let json = #"{"session_id":"abc-123","cwd":"/tmp","hook_event_name":"Notification","transcript_path":"/tmp/t.jsonl","notification_type":"permission_request","message":"Claude wants to run: rm -rf /tmp"}"#
        let event = try CCEventParser.parse(Data(json.utf8))
        XCTAssertEqual(event.sessionID, "abc-123")
        XCTAssertEqual(event.hookEventName, "Notification")
        XCTAssertEqual(event.notificationType, "permission_request")
    }

    func testParsePreToolUse() throws {
        let json = #"{"session_id":"s1","hook_event_name":"PreToolUse","transcript_path":"","cwd":"/tmp","tool_name":"Bash","tool_input":{"command":"npm test"}}"#
        let event = try CCEventParser.parse(Data(json.utf8))
        XCTAssertEqual(event.toolName, "Bash")
        XCTAssertEqual(event.toolInputJSON["command"]?.stringValue, "npm test")
    }

    func testDefensiveParseMalformedJSON() {
        XCTAssertThrowsError(try CCEventParser.parse(Data("not json".utf8)))
    }

    func testDefensiveParseMissingFields() throws {
        let event = try CCEventParser.parse(Data(#"{"session_id":"s","hook_event_name":"Unknown","transcript_path":"","cwd":"/"}"#.utf8))
        XCTAssertEqual(event.sessionID, "s"); XCTAssertNil(event.toolName)
    }

    func testToPerceptAlertForNotification() throws {
        let event = CCEvent(sessionID: "s1", cwd: "/tmp", hookEventName: "Notification",
            transcriptPath: "/tmp/t.jsonl", notificationType: "permission_request", message: "需要你批准")
        let percept = event.toPercept()
        XCTAssertEqual(percept.priority, .alert); XCTAssertEqual(percept.kind, "cc.needs_you")
        XCTAssertFalse(percept.actions.isEmpty)
    }

    func testToPerceptAmbientForPreToolUse() throws {
        let event = CCEvent(sessionID: "s1", cwd: "/tmp", hookEventName: "PreToolUse",
            transcriptPath: "/tmp/t.jsonl", toolName: "Read")
        let percept = event.toPercept()
        XCTAssertEqual(percept.priority, .ambient); XCTAssertEqual(percept.kind, "cc.working")
    }
}
