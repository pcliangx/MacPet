import Foundation

/// M9 插件 manifest（spec §10.2）：plugin.json 解析与校验
public struct PluginManifest: Codable, Equatable, Sendable {
    public let name: String
    public let displayName: String
    public let version: String
    public let kind: [String]                 // ["sense","tool","fuel"]
    public let entry: Entry
    public var permissions: [String] = []     // ["network","read:/path","notify","fuel"]
    public var tools: [ToolDecl] = []
    public var senses: [SenseDecl] = []
    public var personaHints: PersonaHints?

    public struct Entry: Codable, Equatable, Sendable {
        public let type: String               // "exec" | "mcp"
        public let cmd: String
    }
    public struct ToolDecl: Codable, Equatable, Sendable {
        public let name: String
        public let tier: String               // "free-read" | "ask"（never/free-home 不可申领）
    }
    public struct SenseDecl: Codable, Equatable, Sendable {
        public let id: String
        public let priority: String           // "ambient" | "nudge" | "alert"
        public var dailyBudget: Int = 10

        private enum CodingKeys: String, CodingKey { case id, priority, dailyBudget }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            priority = try c.decode(String.self, forKey: .priority)
            dailyBudget = try c.decodeIfPresent(Int.self, forKey: .dailyBudget) ?? 10
        }
    }
    public struct PersonaHints: Codable, Equatable, Sendable {
        public let toyName: String
        public let intro: String
    }

    private enum CodingKeys: String, CodingKey {
        case name, displayName, version, kind, entry, permissions, tools, senses
        case personaHints = "persona_hints"
    }

    /// 自定义解码：permissions/tools/senses/persona_hints 可省略（取默认值）
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        displayName = try c.decode(String.self, forKey: .displayName)
        version = try c.decode(String.self, forKey: .version)
        kind = try c.decode([String].self, forKey: .kind)
        entry = try c.decode(Entry.self, forKey: .entry)
        permissions = try c.decodeIfPresent([String].self, forKey: .permissions) ?? []
        tools = try c.decodeIfPresent([ToolDecl].self, forKey: .tools) ?? []
        senses = try c.decodeIfPresent([SenseDecl].self, forKey: .senses) ?? []
        personaHints = try c.decodeIfPresent(PersonaHints.self, forKey: .personaHints)
    }

    /// 解析 plugin.json
    public static func parse(_ data: Data) throws -> PluginManifest {
        try JSONDecoder().decode(PluginManifest.self, from: data)
    }

    /// 校验合法性。返回违规原因列表（空 = 合格）。
    public func validate() -> [String] {
        var issues: [String] = []
        if name.isEmpty { issues.append("name 不能为空") }
        if !["exec", "mcp"].contains(entry.type) { issues.append("entry.type 必须是 exec 或 mcp") }
        let validKinds: Set<String> = ["sense", "tool", "fuel"]
        for k in kind where !validKinds.contains(k) { issues.append("未知 kind: \(k)") }
        // 工具 tier 申领限制（spec §10.1：never/free-home 不可申领）
        for t in tools {
            if !["free-read", "ask"].contains(t.tier) {
                issues.append("工具 \(t.name) 申领了不允许的 tier: \(t.tier)（只能 free-read 或 ask）")
            }
        }
        for s in senses {
            if !["ambient", "nudge", "alert"].contains(s.priority) {
                issues.append("感官 \(s.id) 优先级非法: \(s.priority)")
            }
            if s.dailyBudget < 0 || s.dailyBudget > 100 {
                issues.append("感官 \(s.id) dailyBudget 超界（0-100）")
            }
        }
        return issues
    }

    /// 转换为核心 ToolSpec（minStage 固定 juvenile，spec §10.8：插件爪子从少年起可用）
    public func toToolSpecs() -> [ToolSpec] {
        tools.compactMap { decl in
            let tier: ToolTier = decl.tier == "free-read" ? .freeRead : .ask
            return ToolSpec(name: "\(name).\(decl.name)",
                            description: "\(displayName) 提供的工具 \(decl.name)",
                            parametersJSON: #"{"type":"object"}"#,
                            tier: tier, minStage: .juvenile)
        }
    }
}
