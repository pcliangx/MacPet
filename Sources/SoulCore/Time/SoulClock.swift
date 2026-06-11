import Foundation

public protocol SoulClock: Sendable { var now: Date { get } }

public struct SystemClock: SoulClock {
    public init() {}
    public var now: Date { Date() }
}

/// 时间旅行测试时钟（开发模式硬约束 §12.5 的根基）
public final class TestClock: SoulClock, @unchecked Sendable {
    private let lock = NSLock()
    private var t: Date
    public init(_ start: Date) { t = start }
    public var now: Date { lock.lock(); defer { lock.unlock() }; return t }
    public func advance(by seconds: TimeInterval) {
        lock.lock(); t = t.addingTimeInterval(seconds); lock.unlock()
    }
}
