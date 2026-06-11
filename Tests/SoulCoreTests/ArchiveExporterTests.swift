import XCTest
@testable import SoulCore

final class ArchiveExporterTests: XCTestCase {
    func testExportImportRoundTrip() throws {
        let memories = [Memory(kind: .episodic, content: "test memory")]
        var growth = GrowthState(); growth.totalXP = 500
        let data = try ArchiveExporter.export(memories: memories, growth: growth, soul: SoulState())
        let archive = try ArchiveExporter.importArchive(data)
        XCTAssertEqual(archive.memories.count, 1)
        XCTAssertEqual(archive.growthState.totalXP, 500)
        XCTAssertEqual(archive.version, 2)  // M7: schema v2（含身份密钥与好友字段）
    }
    func testExportedJSONIsPrettyPrinted() throws {
        let data = try ArchiveExporter.export(memories: [], growth: GrowthState(), soul: SoulState())
        let str = String(data: data, encoding: .utf8)!
        XCTAssertTrue(str.contains("\n"))  // pretty printed
    }
    func testImportRejectsInvalidData() {
        XCTAssertThrowsError(try ArchiveExporter.importArchive(Data("bad".utf8)))
    }

    // ── M7: 身份密钥与好友 ──

    func testExportWithIdentityRoundTrip() throws {
        let identity = PetIdentity.generate(petName: "泡沫", species: "小狐狸")
        let friendId = PetIdentity.generate(petName: "朋友", species: "小猫")
        let friend = Friend(id: friendId.publicKey.base64EncodedString(), card: friendId.card(),
                            relationship: .friend, addedAt: Date(), lastSeen: nil, battleRecord: .init())
        let data = try ArchiveExporter.export(memories: [], growth: GrowthState(), soul: SoulState(),
                                               identity: identity, friends: [friend])
        let archive = try ArchiveExporter.importArchive(data)
        XCTAssertEqual(archive.identity?.publicKey, identity.publicKey)
        XCTAssertEqual(archive.identity?.privateKey, identity.privateKey)  // 私钥随档案（换机不失身份）
        XCTAssertEqual(archive.friends.count, 1)
        XCTAssertEqual(archive.friends.first?.card.petName, "朋友")
    }

    func testV1ArchiveStillImportable() throws {
        // v1 档案没有 identity/friends 字段——必须容忍
        let v1JSON = """
        {"version":1,"exportedAt":"2026-06-12T00:00:00Z","memories":[],
         "growthState":{"schemaVersion":1,"totalXP":100,"todayXP":0,"bond":0,"stage":1,"streakDays":0,"lastActiveDay":"","todayDate":""},
         "soulState":{"schemaVersion":1,"mood":"calm","queuedThoughts":[]}}
        """
        let archive = try ArchiveExporter.importArchive(Data(v1JSON.utf8))
        XCTAssertEqual(archive.version, 1)
        XCTAssertNil(archive.identity)
        XCTAssertTrue(archive.friends.isEmpty)
        XCTAssertEqual(archive.growthState.totalXP, 100)
    }
}
