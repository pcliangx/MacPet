import Foundation

/// M1 修复 #1：daemon 可变状态 actor 化（消除 socket 并发数据竞争）
public actor DaemonSoul {
    private let store: StateStore
    private let clock: SoulClock
    private let watchedBundleIDs: Set<String>
    private let perceptLog: PerceptLog
    private let wakePolicy: WakePolicy
    private var lifecyclePhase: LifecyclePhase = .active
    private let heartbeat: HeartbeatScheduler
    private let attentionSeeker: AttentionSeeker
    private var state: SoulState
    private var lastPresenceCheck: Date
    public private(set) var interactionCount: Int = 0

    // ── Growth (M3) ──
    private var growthState: GrowthState
    private let growthStore: GrowthStateStore

    // ── Memory (M4) ──
    private let memoryStore: MemoryStore

    public init(store: StateStore, growthStore: GrowthStateStore, clock: SoulClock,
                watchedBundleIDs: [String], nudgeBudgetPerHour: Int, genome: Genome,
                memoryStore: MemoryStore) {
        self.store = store; self.clock = clock
        self.watchedBundleIDs = Set(watchedBundleIDs)
        self.perceptLog = PerceptLog(clock: clock)
        self.wakePolicy = WakePolicy(clock: clock, nudgeBudgetPerHour: nudgeBudgetPerHour)
        self.heartbeat = HeartbeatScheduler(clock: clock)
        self.attentionSeeker = AttentionSeeker(budgetPerHour: 2)
        self.state = store.load()
        self.lastPresenceCheck = clock.now
        self.growthStore = growthStore
        self.growthState = growthStore.load()
        self.memoryStore = memoryStore
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

    public var currentPhase: LifecyclePhase { lifecyclePhase }

    public func updateLifecycle(idleMinutes: Int) {
        let hour = Calendar.current.component(.hour, from: clock.now)
        let wasAsleep = lifecyclePhase == .asleep
        lifecyclePhase = LifecyclePhase.resolve(hour: hour, idleMinutes: idleMinutes, wasAsleep: wasAsleep)
        let since = state.lastInteractionAt.map { clock.now.timeIntervalSince($0) } ?? .infinity
        let attention: Attention
        if idleMinutes > 180 { attention = .away }
        else if idleMinutes < 5 { attention = .attending }
        else { attention = .elsewhere }
        let mood = MoodEngine.moodV2(.init(attention: attention, hour: hour,
            secondsSinceInteraction: since, phase: lifecyclePhase))
        state.mood = mood
        try? store.save(state)
    }

    public func checkHeartbeat() async -> (shouldWake: Bool, emote: String?, speech: String?) {
        let idle = idleMinutesFromState()
        guard await heartbeat.shouldFire(lastInteractionMinutesAgo: idle) else { return (false, nil, nil) }
        let (emote, speech) = IdleActions.pick(phase: lifecyclePhase, mood: state.mood)
        return (true, emote, speech)
    }

    public func checkAttentionSeeking(idleMinutes: Int) -> (text: String, emote: String)? {
        guard attentionSeeker.shouldSeekAttention(idleMinutes: idleMinutes, phase: lifecyclePhase) else { return nil }
        attentionSeeker.consumeAttention()
        return (AttentionSeeker.pickAction(mood: state.mood), AttentionSeeker.pickEmote(mood: state.mood))
    }

    public func generateReturnGreeting() -> String? {
        guard lifecyclePhase == .returning else { return nil }
        let minutes = idleMinutesFromState()
        return ReturnDetector.greeting(absenceMinutes: minutes, phase: lifecyclePhase, mood: state.mood)
    }

    private func idleMinutesFromState() -> Int {
        guard let last = state.lastInteractionAt else { return 999 }
        return Int(clock.now.timeIntervalSince(last) / 60)
    }

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
         "stage": .string("\(growthState.stage)"),
         "totalXP": .number(Double(growthState.totalXP)),
         "streakDays": .number(Double(growthState.streakDays)),
         "version": .string(SoulCoreInfo.version),
         "lastInteraction": state.lastInteractionAt.map { .number($0.timeIntervalSince1970) } ?? .null]
    }

    // ── Growth (M3) ──

    public var currentGrowth: GrowthState { growthState }

    public func applyXP(_ amount: Int) {
        growthState.todayXP += amount
        growthState.totalXP += amount
        let newStage = GrowthState.stageForXP(growthState.totalXP)
        if newStage > growthState.stage {
            growthState.stage = newStage
            // TODO: emit evolve directive (handled by caller)
        }
        try? growthStore.save(growthState)
    }

    public func addBond(_ interaction: EconomyEngine.BondInteraction) {
        growthState.bond += EconomyEngine.bondGain(for: interaction)
        try? growthStore.save(growthState)
    }

    public func applyFuelReport(raw: Double) {
        let xp = EconomyEngine.calcXPGain(
            fuelRaw: raw,
            streakMultiplier: EconomyEngine.streakMultiplier(days: growthState.streakDays),
            todayXPSoFar: growthState.todayXP
        )
        if xp > 0 { applyXP(xp) }
    }

    public func dailyRolloverIfNeeded() {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        let today = f.string(from: clock.now)
        guard today != growthState.todayDate else { return }
        // Update streak
        if let lastDay = growthState.lastActiveDay.isEmpty ? nil : growthState.lastActiveDay {
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            if let lastDate = df.date(from: lastDay),
               let expected = Calendar.current.date(byAdding: .day, value: 1, to: lastDate),
               f.string(from: expected) == today {
                growthState.streakDays += 1
            } else {
                growthState.streakDays = 1
            }
        } else {
            growthState.streakDays = 1
        }
        growthState.lastActiveDay = growthState.todayDate
        growthState.todayDate = today
        growthState.todayXP = 0
        try? growthStore.save(growthState)
    }

    public func growthSnapshot() -> [String: JSONValue] {
        ["stage": .string("\(growthState.stage)"),
         "totalXP": .number(Double(growthState.totalXP)),
         "todayXP": .number(Double(growthState.todayXP)),
         "bond": .number(Double(growthState.bond)),
         "streakDays": .number(Double(growthState.streakDays)),
         "progress": .number(growthState.progressToNext)]
    }

    // ── Memory (M4) ──

    public var memoryCount: Int { memoryStore.count() }

    public func addMemory(_ memory: Memory) { memoryStore.add(memory) }

    public func recallMemories(query: String, limit: Int = 5) -> [Memory] {
        MemorySearch.search(query: query, in: memoryStore.getAll(), limit: limit)
    }

    public func performDream() -> (diaryEntry: String, newSemantics: [Memory], milestones: [Memory]) {
        let episodic = memoryStore.getAll().filter { $0.kind == .episodic }
        let newSemantics = DreamEngine.distill(episodic: episodic)
        let milestones = DreamEngine.checkMilestones(growthState: growthState)
        // Add new memories
        newSemantics.forEach { memoryStore.add($0) }
        milestones.forEach { memoryStore.add($0) }
        // Write diary
        let entry = DiaryWriter.writeEntry(date: clock.now, events: episodic, mood: state.mood, stage: growthState.stage)
        return (entry, newSemantics, milestones)
    }

    public func exportArchive() throws -> Data {
        try ArchiveExporter.export(memories: memoryStore.getAll(), growth: growthState, soul: state)
    }

    public func importArchive(_ data: Data) throws {
        let archive = try ArchiveExporter.importArchive(data)
        growthState = archive.growthState
        state = archive.soulState
        // Replace memories
        for m in memoryStore.getAll() { memoryStore.delete(id: m.id) }
        for m in archive.memories { memoryStore.add(m) }
        try? growthStore.save(growthState)
        try? store.save(state)
    }

    /// Get top memories for persona prompt
    public func topMemoriesForPrompt(query: String = "", limit: Int = 3) -> [Memory] {
        MemorySearch.search(query: query, in: memoryStore.getAll(), limit: limit)
    }
}
