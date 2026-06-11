import Foundation

public enum ArchiveExporter {
    public struct LifeArchive: Codable {
        public var version: Int = 2          // M7: 含身份密钥与好友
        public var exportedAt: Date
        public var memories: [Memory]
        public var growthState: GrowthState
        public var soulState: SoulState
        public var identity: PetIdentity?    // M7: 身份密钥（换机不失身份，spec §12#2）
        public var friends: [Friend]         // M7: 好友档案

        // 容忍 v1 档案（无 identity/friends 字段）
        private enum CodingKeys: String, CodingKey {
            case version, exportedAt, memories, growthState, soulState, identity, friends
        }
        public init(exportedAt: Date, memories: [Memory], growthState: GrowthState,
                    soulState: SoulState, identity: PetIdentity? = nil, friends: [Friend] = []) {
            self.exportedAt = exportedAt; self.memories = memories
            self.growthState = growthState; self.soulState = soulState
            self.identity = identity; self.friends = friends
        }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
            exportedAt = try c.decode(Date.self, forKey: .exportedAt)
            memories = try c.decode([Memory].self, forKey: .memories)
            growthState = try c.decode(GrowthState.self, forKey: .growthState)
            soulState = try c.decode(SoulState.self, forKey: .soulState)
            identity = try c.decodeIfPresent(PetIdentity.self, forKey: .identity)
            friends = try c.decodeIfPresent([Friend].self, forKey: .friends) ?? []
        }
    }

    public static func export(memories: [Memory], growth: GrowthState, soul: SoulState,
                              identity: PetIdentity? = nil, friends: [Friend] = []) throws -> Data {
        let archive = LifeArchive(exportedAt: Date(), memories: memories, growthState: growth,
                                   soulState: soul, identity: identity, friends: friends)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(archive)
    }

    public static func importArchive(_ data: Data) throws -> LifeArchive {
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return try dec.decode(LifeArchive.self, from: data)
    }
}
