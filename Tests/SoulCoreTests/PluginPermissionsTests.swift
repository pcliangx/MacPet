import XCTest
@testable import SoulCore

final class PluginPermissionsTests: XCTestCase {
    func tempDir() -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true); return u
    }
    func testParsePermissions() {
        XCTAssertEqual(PluginPermission.parse("network"), .network)
        XCTAssertEqual(PluginPermission.parse("read:/tmp"), .readPath("/tmp"))
        XCTAssertEqual(PluginPermission.parse("fuel"), .fuel)
        XCTAssertNil(PluginPermission.parse("write:/etc"))  // 不存在的权限
    }
    func testFuelIsSensitive() {
        XCTAssertTrue(PluginPermission.fuel.isSensitive)
        XCTAssertFalse(PluginPermission.network.isSensitive)
    }
    func testGrantAndCheck() {
        let store = PluginPermissionStore(directory: tempDir())
        store.grant(plugin: "weather", permission: .network)
        XCTAssertTrue(store.isGranted(plugin: "weather", permission: .network))
        XCTAssertFalse(store.isGranted(plugin: "weather", permission: .fuel))
    }
    func testRevoke() {
        let store = PluginPermissionStore(directory: tempDir())
        store.grant(plugin: "p", permission: .notify)
        store.revoke(plugin: "p", permission: .notify)
        XCTAssertFalse(store.isGranted(plugin: "p", permission: .notify))
    }
    func testPersistence() {
        let dir = tempDir()
        let s1 = PluginPermissionStore(directory: dir)
        s1.grant(plugin: "p", permission: .network)
        let s2 = PluginPermissionStore(directory: dir)
        XCTAssertTrue(s2.isGranted(plugin: "p", permission: .network))
    }
    func testFuelKindAutoAddsPermission() throws {
        let json = """
        {"name":"cc","displayName":"CC","version":"1.0","kind":["fuel"],
         "entry":{"type":"exec","cmd":"./cc"}}
        """
        let m = try PluginManifest.parse(Data(json.utf8))
        let pending = PluginPermissionStore.pendingConfirmations(manifest: m)
        XCTAssertTrue(pending.contains(.fuel))
    }
    func testSensitiveSortedLast() throws {
        let json = """
        {"name":"x","displayName":"X","version":"1.0","kind":["sense","fuel"],
         "entry":{"type":"exec","cmd":"./x"},
         "permissions":["fuel","network","notify"]}
        """
        let m = try PluginManifest.parse(Data(json.utf8))
        let pending = PluginPermissionStore.pendingConfirmations(manifest: m)
        XCTAssertEqual(pending.last, .fuel)
    }
}
