import XCTest
@testable import SoulCore

final class MCPBridgeTests: XCTestCase {
    func testParseToolsList() throws {
        let json = """
        {"jsonrpc":"2.0","id":1,"result":{"tools":[
          {"name":"get_weather","description":"获取天气","inputSchema":{"type":"object","properties":{"city":{"type":"string"}}}},
          {"name":"get_time","description":"获取时间"}
        ]}}
        """
        let tools = try MCPBridge.parseToolsList(Data(json.utf8))
        XCTAssertEqual(tools.count, 2)
        XCTAssertEqual(tools[0].name, "get_weather")
    }
    func testToToolSpecsDefaultsToAsk() throws {
        let tools = [MCPBridge.MCPToolDef(name: "test", description: "desc", inputSchema: nil)]
        let specs = MCPBridge.toToolSpecs(mcpTools: tools, pluginName: "myplugin")
        XCTAssertEqual(specs.first?.tier, .ask)
        XCTAssertEqual(specs.first?.name, "myplugin.test")
        XCTAssertEqual(specs.first?.minStage, .juvenile)
    }
    func testNotificationToPercept() {
        let p = MCPBridge.notificationToPercept(method: "resourceUpdated", pluginName: "files")
        XCTAssertEqual(p.priority, .ambient)
        XCTAssertEqual(p.kind, "files.resourceUpdated")
    }
    func testParseRejectsGarbage() {
        XCTAssertThrowsError(try MCPBridge.parseToolsList(Data("bad".utf8)))
    }
}
