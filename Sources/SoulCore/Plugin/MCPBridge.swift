import Foundation

/// M9 MCP 桥（spec §10.4）：MCP server 的 tools 映射进工具箱（默认 ask 级），notifications 映射为 ambient 感官
public enum MCPBridge {
    /// MCP tools/list 响应中的工具定义
    public struct MCPToolDef: Codable, Equatable, Sendable {
        public let name: String
        public let description: String?
        public let inputSchema: JSONValue?

        public init(name: String, description: String?, inputSchema: JSONValue?) {
            self.name = name; self.description = description; self.inputSchema = inputSchema
        }
    }

    /// 解析 MCP tools/list 响应（JSON-RPC result.tools）
    public static func parseToolsList(_ data: Data) throws -> [MCPToolDef] {
        struct Response: Codable { struct R: Codable { let tools: [MCPToolDef] }; let result: R }
        return try JSONDecoder().decode(Response.self, from: data).result.tools
    }

    /// MCP 工具 → mpet ToolSpec（默认 ask 级，spec §10.4；插件名命名空间防冲突）
    public static func toToolSpecs(mcpTools: [MCPToolDef], pluginName: String) -> [ToolSpec] {
        mcpTools.map { tool in
            let schemaJSON: String
            if let schema = tool.inputSchema, let data = try? JSONEncoder().encode(schema),
               let s = String(data: data, encoding: .utf8) { schemaJSON = s }
            else { schemaJSON = #"{"type":"object"}"# }
            return ToolSpec(name: "\(pluginName).\(tool.name)",
                            description: tool.description ?? tool.name,
                            parametersJSON: schemaJSON,
                            tier: .ask,           // MCP 工具默认「先问」级
                            minStage: .juvenile)  // 插件爪子从少年起
        }
    }

    /// MCP notification → ambient 感官事件
    public static func notificationToPercept(method: String, pluginName: String) -> Percept {
        Percept(kind: "\(pluginName).\(method)", priority: .ambient,
                payload: ["source": .string("mcp")], at: Date())
    }
}
