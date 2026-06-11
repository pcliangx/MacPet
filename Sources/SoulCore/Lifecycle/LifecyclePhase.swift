import Foundation

/// M2 生命周期阶段
public enum LifecyclePhase: String, Codable, Sendable {
    case active, drowsy, asleep, returning

    public static func resolve(hour: Int, idleMinutes: Int, wasAsleep: Bool,
                                nightHours: Set<Int> = [23, 0, 1, 2, 3, 4, 5],
                                returnThreshold: Int = 120) -> LifecyclePhase {
        // Waking from night sleep: recently in night hours, now active window
        if wasAsleep && idleMinutes < 30 {
            let recentWindow = (0..<8).map { (hour - $0 + 24) % 24 }
            if recentWindow.contains(where: { nightHours.contains($0) }) { return .returning }
        }
        if wasAsleep { return .asleep }
        if idleMinutes >= returnThreshold && !nightHours.contains(hour) { return .returning }
        if nightHours.contains(hour) && idleMinutes >= 60 { return .asleep }
        if nightHours.contains(hour) { return .drowsy }
        return .active
    }
}
