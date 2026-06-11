// Tests/SoulCoreTests/CCSpoolMonitorTests.swift
import XCTest
@testable import SoulCore

final class CCSpoolMonitorTests: XCTestCase {
    func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true); return u
    }

    func testDetectsNewFiles() async throws {
        let dir = tempDir(); let monitor = CCSpoolMonitor(spoolDir: dir)
        var events: [CCEvent] = []
        await monitor.setHandler { events.append($0) }
        await monitor.start()
        let eventData = #"{"session_id":"s1","hook_event_name":"Notification","transcript_path":"/tmp/t.jsonl","cwd":"/tmp","message":"CC 需要你"}"#
        let file = dir.appendingPathComponent("\(Int(Date().timeIntervalSince1970 * 1000)).json")
        try Data(eventData.utf8).write(to: file, options: .atomic)
        let deadline = Date().addingTimeInterval(3)
        while events.isEmpty && Date() < deadline { try await Task.sleep(nanoseconds: 100_000_000) }
        await monitor.stop()
        XCTAssertEqual(events.count, 1); XCTAssertEqual(events.first?.sessionID, "s1")
    }

    func testIgnoresAlreadyProcessedFiles() async throws {
        let dir = tempDir()
        try #"{"session_id":"old"}"#.write(to: dir.appendingPathComponent("old.json"), atomically: true, encoding: .utf8)
        let monitor = CCSpoolMonitor(spoolDir: dir)
        var events: [CCEvent] = []
        await monitor.setHandler { events.append($0) }
        await monitor.start()
        try await Task.sleep(nanoseconds: 500_000_000)
        await monitor.stop()
        XCTAssertTrue(events.isEmpty)
    }

    func testMalformedFileIsSkippedGracefully() async throws {
        let dir = tempDir(); let monitor = CCSpoolMonitor(spoolDir: dir)
        var events: [CCEvent] = []
        await monitor.setHandler { events.append($0) }
        await monitor.start()
        try Data("not json".utf8).write(to: dir.appendingPathComponent("\(Int(Date().timeIntervalSince1970 * 1000)).json"))
        try await Task.sleep(nanoseconds: 50_000_000)
        let goodData = #"{"session_id":"s2","hook_event_name":"Stop","transcript_path":"","cwd":"/"}"#
        try goodData.write(to: dir.appendingPathComponent("\(Int(Date().timeIntervalSince1970 * 1000) + 1).json"), atomically: true, encoding: .utf8)
        let deadline = Date().addingTimeInterval(3)
        while events.isEmpty && Date() < deadline { try await Task.sleep(nanoseconds: 100_000_000) }
        await monitor.stop()
        XCTAssertEqual(events.count, 1); XCTAssertEqual(events.first?.sessionID, "s2")
    }
}
