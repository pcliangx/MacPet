import Foundation

/// M2 定时心跳调度（spec §5.2："每日少量定时心跳"）
public actor HeartbeatScheduler {
    private let clock: SoulClock
    private let intervalMinutes: Int
    private let dailyBudget: Int
    private var lastFire: Date
    private var dayStart: Date
    private var firesToday: Int = 0

    public init(clock: SoulClock, intervalMinutes: Int = 30, dailyBudget: Int = 12) {
        self.clock = clock; self.intervalMinutes = intervalMinutes; self.dailyBudget = dailyBudget
        self.lastFire = clock.now.addingTimeInterval(-Double(intervalMinutes * 60))
        self.dayStart = Calendar.current.startOfDay(for: clock.now)
    }

    public func shouldFire(lastInteractionMinutesAgo: Int = 999) -> Bool {
        guard lastInteractionMinutesAgo >= 15 else { return false }
        let now = clock.now
        let todayStart = Calendar.current.startOfDay(for: now)
        if todayStart > dayStart { dayStart = todayStart; firesToday = 0 }
        guard now.timeIntervalSince(lastFire) >= Double(intervalMinutes * 60) else { return false }
        guard firesToday < dailyBudget else { return false }
        lastFire = now; firesToday += 1
        return true
    }
}
