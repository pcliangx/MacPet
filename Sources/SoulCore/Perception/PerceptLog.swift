// Sources/SoulCore/Perception/PerceptLog.swift
import Foundation

/// 近期感知环形缓冲：唤醒时的「近期事件摘要」来源。ambient 同类合并防事件风暴。
public final class PerceptLog: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [Percept] = []
    private let capacity: Int
    private let coalesceWindow: TimeInterval
    private let clock: SoulClock

    public init(capacity: Int = 50, coalesceWindow: TimeInterval = 60, clock: SoulClock) {
        self.capacity = capacity; self.coalesceWindow = coalesceWindow; self.clock = clock
    }
    public func add(_ p: Percept) {
        lock.lock(); defer { lock.unlock() }
        if p.priority == .ambient,
           let last = items.last, last.kind == p.kind, last.priority == .ambient,
           clock.now.timeIntervalSince(last.at) < coalesceWindow {
            items[items.count - 1] = p          // 合并：保留最新
            return
        }
        items.append(p)
        if items.count > capacity { items.removeFirst(items.count - capacity) }
    }
    public func recent(limit: Int) -> [Percept] {
        lock.lock(); defer { lock.unlock() }
        return Array(items.suffix(limit))
    }
}
