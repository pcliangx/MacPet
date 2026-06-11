import XCTest
@testable import SoulCore

final class PluginProcessManagerTests: XCTestCase {
    func makeManifest(name: String, cmd: String = "sleep 60") -> PluginManifest {
        try! PluginManifest.parse(Data("""
        {"name":"\(name)","displayName":"\(name)","version":"1.0","kind":["sense"],
         "entry":{"type":"exec","cmd":"\(cmd)"}}
        """.utf8))
    }
    func testRegisterPlugin() async {
        let mgr = PluginProcessManager()
        await mgr.register(manifest: makeManifest(name: "test"))
        let count = await mgr.registeredCount
        XCTAssertEqual(count, 1)
        let status = await mgr.status(of: "test")
        XCTAssertEqual(status, .stopped)
    }
    func testStartAndStop() async {
        let mgr = PluginProcessManager()
        await mgr.register(manifest: makeManifest(name: "test"))
        let started = await mgr.start(name: "test")
        XCTAssertTrue(started)
        let runningStatus = await mgr.status(of: "test")
        XCTAssertEqual(runningStatus, .running)
        await mgr.stop(name: "test")
        let stoppedStatus = await mgr.status(of: "test")
        XCTAssertEqual(stoppedStatus, .stopped)
    }
    func testDisablePreventsStart() async {
        let mgr = PluginProcessManager()
        await mgr.register(manifest: makeManifest(name: "test"))
        await mgr.disable(name: "test")
        let started = await mgr.start(name: "test")
        XCTAssertFalse(started)
    }
    func testEnableResetsRestartCount() async {
        let mgr = PluginProcessManager()
        await mgr.register(manifest: makeManifest(name: "test"))
        await mgr.disable(name: "test")
        await mgr.enable(name: "test")
        let status = await mgr.status(of: "test")
        XCTAssertEqual(status, .stopped)
        let count = await mgr.restartCount(of: "test")
        XCTAssertEqual(count, 0)
    }
    func testMCPEntryTypeCannotExecStart() async {
        let mcp = try! PluginManifest.parse(Data("""
        {"name":"mcp-test","displayName":"M","version":"1.0","kind":["tool"],
         "entry":{"type":"mcp","cmd":"npx some-server"}}
        """.utf8))
        let mgr = PluginProcessManager()
        await mgr.register(manifest: mcp)
        let started = await mgr.start(name: "mcp-test")
        XCTAssertFalse(started)  // mcp 型不走 exec 启动
    }
}
