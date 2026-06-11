import Foundation

public enum ArchiveExporter {
    public struct LifeArchive: Codable {
        public var version: Int = 1
        public var exportedAt: Date
        public var memories: [Memory]
        public var growthState: GrowthState
        public var soulState: SoulState
    }

    public static func export(memories: [Memory], growth: GrowthState, soul: SoulState) throws -> Data {
        let archive = LifeArchive(exportedAt: Date(), memories: memories, growthState: growth, soulState: soul)
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(archive)
    }

    public static func importArchive(_ data: Data) throws -> LifeArchive {
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return try dec.decode(LifeArchive.self, from: data)
    }
}
