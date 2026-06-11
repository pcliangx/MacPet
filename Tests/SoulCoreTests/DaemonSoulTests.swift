import XCTest
@testable import SoulCore

final class DaemonSoulTests: XCTestCase {
    func testConcurrentEventsDoNotRace() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let growthDir = dir.appendingPathComponent("growth")
        try! FileManager.default.createDirectory(at: growthDir, withIntermediateDirectories: true)
        let memoryDir = dir.appendingPathComponent("memory")
        let roomDir = dir.appendingPathComponent("room")
        let projectDir = dir.appendingPathComponent("projects")
        let daemon = DaemonSoul(store: StateStore(directory: dir, clock: clock),
                                growthStore: GrowthStateStore(directory: growthDir, clock: clock), clock: clock,
                                watchedBundleIDs: ["com.apple.Terminal"], nudgeBudgetPerHour: 4, genome: .default,
                                memoryStore: MemoryStore(directory: memoryDir),
                                roomStore: PetRoomStore(directory: roomDir),
                                projectStore: PetProjectStore(directory: projectDir))
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 { group.addTask { await daemon.handleEvent(kind: "click", payload: ["i": .number(Double(i))]) } }
        }
        let count = await daemon.interactionCount
        XCTAssertEqual(count, 100)
    }
    func testChatUpdatesLastInteraction() async {
        let clock = TestClock(Date(timeIntervalSince1970: 1_000_000))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let growthDir = dir.appendingPathComponent("growth")
        try! FileManager.default.createDirectory(at: growthDir, withIntermediateDirectories: true)
        let memoryDir = dir.appendingPathComponent("memory")
        let roomDir = dir.appendingPathComponent("room")
        let projectDir = dir.appendingPathComponent("projects")
        let daemon = DaemonSoul(store: StateStore(directory: dir, clock: clock),
                                growthStore: GrowthStateStore(directory: growthDir, clock: clock), clock: clock,
                                watchedBundleIDs: [], nudgeBudgetPerHour: 4, genome: .default,
                                memoryStore: MemoryStore(directory: memoryDir),
                                roomStore: PetRoomStore(directory: roomDir),
                                projectStore: PetProjectStore(directory: projectDir))
        await daemon.noteInteraction()
        let last = await daemon.lastInteractionAt
        XCTAssertNotNil(last)
    }
    func testMoodIsPersistedAfterComputation() async {
        let clock = TestClock(Date(timeIntervalSince1970: 0))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let growthDir = dir.appendingPathComponent("growth")
        try! FileManager.default.createDirectory(at: growthDir, withIntermediateDirectories: true)
        let store = StateStore(directory: dir, clock: clock)
        let memoryDir = dir.appendingPathComponent("memory")
        let roomDir = dir.appendingPathComponent("room")
        let projectDir = dir.appendingPathComponent("projects")
        let daemon = DaemonSoul(store: store,
                                growthStore: GrowthStateStore(directory: growthDir, clock: clock), clock: clock,
                                watchedBundleIDs: [], nudgeBudgetPerHour: 4, genome: .default,
                                memoryStore: MemoryStore(directory: memoryDir),
                                roomStore: PetRoomStore(directory: roomDir),
                                projectStore: PetProjectStore(directory: projectDir))
        // Use Calendar to get a night hour relative to current time
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
}
