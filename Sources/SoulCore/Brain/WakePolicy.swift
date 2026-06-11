// Sources/SoulCore/Brain/WakePolicy.swift
import Foundation

/// 它的作息生理学（spec §5.2）：分的是"什么时候醒"，不是"用几成脑子"。
/// alert 立即唤醒；nudge 受小时预算；ambient 只进上下文。插件 dailyBudget 在 M9 叠加。
public actor WakePolicy {
    private let clock: SoulClock
    private let nudgeBudgetPerHour: Int
    private var windowStart: Date
    private var nudgesInWindow = 0

    public init(clock: SoulClock, nudgeBudgetPerHour: Int = 4) {
        self.clock = clock
        self.nudgeBudgetPerHour = nudgeBudgetPerHour
        self.windowStart = clock.now
    }

    public func shouldWake(for p: Percept) -> Bool {
        switch p.priority {
        case .alert: return true
        case .ambient: return false
        case .nudge:
            if clock.now.timeIntervalSince(windowStart) >= 3600 {
                windowStart = clock.now; nudgesInWindow = 0
            }
            guard nudgesInWindow < nudgeBudgetPerHour else { return false }
            nudgesInWindow += 1
            return true
        }
    }
}
