import Foundation

/// M1 修复 #1：daemon 可变状态 actor 化（消除 socket 并发数据竞争）
public actor DaemonSoul {
    private let store: StateStore
    private let clock: SoulClock
    private let watchedBundleIDs: Set<String>
    private let perceptLog: PerceptLog
    private let wakePolicy: WakePolicy
    private var state: SoulState
    public private(set) var interactionCount: Int = 0

    public init(store: StateStore, clock: SoulClock,
                watchedBundleIDs: [String], nudgeBudgetPerHour: Int, genome: Genome) {
        self.store = store; self.clock = clock
        self.watchedBundleIDs = Set(watchedBundleIDs)
        self.perceptLog = PerceptLog(clock: clock)
        self.wakePolicy = WakePolicy(clock: clock, nudgeBudgetPerHour: nudgeBudgetPerHour)
        self.state = store.load()
    }

    public func noteInteraction() {
        state.lastInteractionAt = clock.now
        interactionCount += 1
        try? store.save(state)
    }
    public var lastInteractionAt: Date? { state.lastInteractionAt }

    public func recomputeMood(attention: Attention) {
        let since = state.lastInteractionAt.map { clock.now.timeIntervalSince($0) } ?? .infinity
        let hour = Calendar.current.component(.hour, from: clock.now)
        let mood = MoodEngine.mood(.init(attention: attention, hour: hour, secondsSinceInteraction: since))
        state.mood = mood
        try? store.save(state)
    }
    public var currentMood: Mood { state.mood }

    public func handleEvent(kind: String, payload: [String: JSONValue]) {
        noteInteraction()
        let percept = Percept(kind: "body.\(kind)", priority: .nudge, payload: payload, at: clock.now)
        perceptLog.add(percept)
    }

    public func handlePercept(_ p: Percept) -> (directives: [PeripheralMessage], shouldWake: Bool) {
        perceptLog.add(p)
        let snap = PresenceSnapshot(frontmostBundleID: nil, idleSeconds: 0, watchedBundleIDs: watchedBundleIDs)
        let attention = AttentionResolver.resolve(snap)
        let mood = state.mood
        let directives = ReflexArc.directives(for: p, attention: attention, mood: mood)
        return (directives, p.priority == .alert)
    }

    public func recentPercepts(limit: Int) -> [Percept] { perceptLog.recent(limit: limit) }

    public func shouldWake(for p: Percept) async -> Bool { await wakePolicy.shouldWake(for: p) }

    public func statusSnapshot(attention: Attention) -> [String: JSONValue] {
        ["mood": .string(state.mood.rawValue),
         "attention": .string(attention.rawValue),
         "stage": .string("baby"),
         "version": .string(SoulCoreInfo.version),
         "lastInteraction": state.lastInteractionAt.map { .number($0.timeIntervalSince1970) } ?? .null]
    }
}
