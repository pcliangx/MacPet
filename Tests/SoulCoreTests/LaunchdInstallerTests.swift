import XCTest
@testable import SoulCore

final class LaunchdInstallerTests: XCTestCase {
    func testPlistGeneration() {
        let plist = LaunchdInstaller.generatePlist(label: "com.mpet.soul", programPath: "/usr/local/bin/mpet-soul",
                                                    keepAlive: true, runAtLoad: true)
        XCTAssertTrue(plist.contains("<key>Label</key>"))
        XCTAssertTrue(plist.contains("<string>com.mpet.soul</string>"))
        XCTAssertTrue(plist.contains("<key>ProgramArguments</key>"))
        XCTAssertTrue(plist.contains("/usr/local/bin/mpet-soul"))
        XCTAssertTrue(plist.contains("<key>KeepAlive</key>"))
        XCTAssertTrue(plist.contains("<key>RunAtLoad</key>"))
    }
    func testInstallWritesPlistFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let plistPath = dir.appendingPathComponent("com.mpet.soul.plist")
        try LaunchdInstaller.install(label: "com.mpet.soul", programPath: "/usr/local/bin/mpet-soul", plistDestination: plistPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: plistPath.path))
        let content = try String(contentsOf: plistPath, encoding: .utf8)
        XCTAssertTrue(content.contains("com.mpet.soul"))
    }
    func testUninstallRemovesPlist() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let plistPath = dir.appendingPathComponent("com.mpet.soul.plist")
        try "test".write(to: plistPath, atomically: true, encoding: .utf8)
        try LaunchdInstaller.uninstall(plistPath: plistPath, skipLaunchctl: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: plistPath.path))
    }
    func testPlistIncludesWorkingDirectory() {
        let plist = LaunchdInstaller.generatePlist(label: "com.mpet.soul", programPath: "/usr/local/bin/mpet-soul",
                                                    workingDirectory: "/Users/test/Library/Application Support/mpet", keepAlive: true)
        XCTAssertTrue(plist.contains("<key>WorkingDirectory</key>"))
        XCTAssertTrue(plist.contains("Application Support/mpet"))
    }
}
