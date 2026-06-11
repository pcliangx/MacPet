import Foundation

public enum DayRollover {
    /// 上次活跃日与现在之间隔了几个"天边界"——睡眠/时区跳变后的补结算依据
    public static func missedDays(from last: Date, to now: Date, calendar: Calendar = .current) -> Int {
        let a = calendar.startOfDay(for: last)
        let b = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: a, to: b).day ?? 0)
    }
}
