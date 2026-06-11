import XCTest
@testable import SoulCore

final class DaemonSoulTests: XCTestCase {
    func makeDaemon(clock: TestClock, watched: [String] = [], dir: URL? = nil) -> (DaemonSoul, StateStore) {
        let base = dir ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let growthDir = base.appendingPathComponent("growth")
        try! FileManager.default.createDirectory(at: growthDir, withIntermediateDirectories: true)
        let store = StateStore(directory: base, clock: clock)
        let daemon = DaemonSoul(
            store: store,
            growthStore: GrowthStateStore(directory: growthDir, clock: clock),
            memoryStore: MemoryStore(directory: base.appendingPathComponent("memory")),
            roomStore: PetRoomStore(directory: base.appendingPathComponent("room")),
            projectStore: PetProjectStore(directory: base.appendingPathComponent("projects")),
            friendStore: FriendStore(directory: base.appendingPathComponent("friends")),
            clock: clock,
            watchedBundleIDs: watched, nudgeBudgetPerHour: 4, genome: .default
        )
        return (daemon, store)
    }

    func testConcurrentEventsDoNotRace() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let (daemon, _) = makeDaemon(clock: clock, watched: ["com.apple.Terminal"])
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 { group.addTask { await daemon.handleEvent(kind: "click", payload: ["i": .number(Double(i))]) } }
        }
        let count = await daemon.interactionCount
        XCTAssertEqual(count, 100)
    }

    func testChatUpdatesLastInteraction() async {
        let clock = TestClock(Date(timeIntervalSince1970: 1_000_000))
        let (daemon, _) = makeDaemon(clock: clock)
        await daemon.noteInteraction()
        let last = await daemon.lastInteractionAt
        XCTAssertNotNil(last)
    }

    func testMoodIsPersistedAfterComputation() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let (daemon, store) = makeDaemon(clock: clock)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        let nightComponents = DateComponents(hour: 2, minute: 0)
        if let nightDate = cal.nextDate(after: clock.now, matching: nightComponents, matchingPolicy: .nextTime) {
            clock.advance(by: nightDate.timeIntervalSince(clock.now))
        }
        await daemon.recomputeMood(attention: .attending)
        let mood = await daemon.currentMood
        XCTAssertEqual(mood, .sleepy)
        let saved = store.load()
        XCTAssertEqual(saved.mood, .sleepy)
    }

    // ── M7 social tests ──

    func testEnsureIdentityIsStable() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let (daemon, _) = makeDaemon(clock: clock)
        let id1 = await daemon.ensureIdentity(petName: "泡沫", species: "小狐狸")
        let id2 = await daemon.ensureIdentity(petName: "别名", species: "别物种")
        XCTAssertEqual(id1.publicKey, id2.publicKey)  // 第二次调用返回同一身份
        let has = await daemon.hasIdentity
        XCTAssertTrue(has)
    }

    func testAddFriendAndBattle() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let (daemon, _) = makeDaemon(clock: clock)
        _ = await daemon.ensureIdentity(petName: "泡沫", species: "小狐狸")
        let friendIdentity = PetIdentity.generate(petName: "对手", species: "小猫")
        let ticket = FriendTicket.create(from: friendIdentity)
        let friend = await daemon.addFriend(from: ticket)
        let count = await daemon.friendCount()
        XCTAssertEqual(count, 1)
        let result = await daemon.initiateBattle(friendId: friend.id, seed: 42)
        XCTAssertNotNil(result)
        XCTAssertFalse(result!.narrative.isEmpty)
    }

    func testArchiveWithIdentityRoundTrip() async throws {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let (daemon, _) = makeDaemon(clock: clock)
        let identity = await daemon.ensureIdentity(petName: "泡沫", species: "小狐狸")
        let data = try await daemon.exportArchiveWithIdentity()
        let archive = try ArchiveExporter.importArchive(data)
        XCTAssertEqual(archive.identity?.publicKey, identity.publicKey)
        XCTAssertEqual(archive.version, 2)
    }

    // ── M8 plaza & gating tests ──

    func attachStores(to daemon: DaemonSoul) async -> URL {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        await daemon.attachSocialStores(
            plaza: PlazaSightingStore(directory: base.appendingPathComponent("plaza")),
            safety: SocialSafety(directory: base.appendingPathComponent("safety")),
            badges: BadgeCollectionStore(directory: base.appendingPathComponent("badges"))
        )
        return base
    }

    func testStageGatingForSocial() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let (daemon, _) = makeDaemon(clock: clock)
        // baby 阶段：不可串门、不可广场、不可天梯
        let canVisit = await daemon.canVisitFriends
        let canPlaza = await daemon.canUsePlaza
        let canLadder = await daemon.canUseLadder
        XCTAssertFalse(canVisit)
        XCTAssertFalse(canPlaza)
        XCTAssertFalse(canLadder)
    }

    func testBadgeUnlockOnFirstFriend() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let (daemon, _) = makeDaemon(clock: clock)
        _ = await attachStores(to: daemon)
        let friendIdentity = PetIdentity.generate(petName: "朋友", species: "小猫")
        _ = await daemon.addFriend(from: FriendTicket.create(from: friendIdentity))
        let badges = await daemon.checkBadges()
        XCTAssertTrue(badges.contains { $0.id == "first-friend" })
    }

    func testSocialInteractionBlockedWithoutStores() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let (daemon, _) = makeDaemon(clock: clock)
        // 未 attach safety store → 默认拒绝
        let allowed = await daemon.allowsSocialInteraction(nodeId: "anyone")
        XCTAssertFalse(allowed)
    }
}
