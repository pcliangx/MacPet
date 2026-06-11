// Tests/SoulCoreTests/HookInstallerTests.swift
import XCTest
@testable import SoulCore

final class HookInstallerTests: XCTestCase {
    func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true); return u
    }

    func testInstallCreatesBackupAndPatchesHooks() throws {
        let dir = tempDir(); let f = dir.appendingPathComponent("settings.json")
        try Data(#"{"hooks":{},"model":"opus"}"#.utf8).write(to: f)
        try HookInstaller(settingsPath: f).install(hookCommand: "cat > /tmp/spool/event.json")
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.contains("backup-mpet-hook") }
        XCTAssertFalse(backups.isEmpty)
        let updated = try String(data: Data(contentsOf: f), encoding: .utf8)!
        XCTAssertTrue(updated.contains("backup-mpet-hook") || updated.contains("event.json"))
        XCTAssertTrue(updated.contains("opus"))
    }

    func testInstallIdempotent() throws {
        let dir = tempDir(); let f = dir.appendingPathComponent("settings.json")
        try Data(#"{"hooks":{}}"#.utf8).write(to: f)
        let inst = HookInstaller(settingsPath: f)
        try inst.install(hookCommand: "echo test"); try inst.install(hookCommand: "echo test")
        let data = try Data(contentsOf: f)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = json["hooks"] as! [String: Any]
        let notifs = hooks["Notification"] as! [[String: Any]]
        let inner = notifs[0]["hooks"] as! [[String: Any]]
        XCTAssertEqual(inner.count, 1)
    }

    func testUninstallRemovesMpetHooks() throws {
        let dir = tempDir(); let f = dir.appendingPathComponent("settings.json")
        try Data(#"{"hooks":{},"theme":"dark"}"#.utf8).write(to: f)
        let inst = HookInstaller(settingsPath: f)
        try inst.install(hookCommand: "echo test"); try inst.uninstall()
        let data = try Data(contentsOf: f)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = json["hooks"] as! [String: Any]
        XCTAssertNil(hooks["Notification"])
        XCTAssertEqual(json["theme"] as? String, "dark")
    }

    func testCreatesSettingsFileIfMissing() throws {
        let dir = tempDir(); let f = dir.appendingPathComponent("settings.json")
        try HookInstaller(settingsPath: f).install(hookCommand: "echo test")
        XCTAssertTrue(FileManager.default.fileExists(atPath: f.path))
    }
}
