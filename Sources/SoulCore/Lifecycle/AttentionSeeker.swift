import Foundation

/// M2 求关注（spec §6.4）
public final class AttentionSeeker: @unchecked Sendable {
    private let lock = NSLock()
    private let budgetPerHour: Int
    private var usedThisHour: Int = 0
    private var windowStart: Date = Date()

    public init(budgetPerHour: Int = 2) { self.budgetPerHour = budgetPerHour }

    public func shouldSeekAttention(idleMinutes: Int, phase: LifecyclePhase) -> Bool {
        guard phase == .active, idleMinutes >= 30 else { return false }
        lock.lock(); defer { lock.unlock() }
        if Date().timeIntervalSince(windowStart) >= 3600 { windowStart = Date(); usedThisHour = 0 }
        return usedThisHour < budgetPerHour
    }

    public func consumeAttention() {
        lock.lock(); defer { lock.unlock() }
        if Date().timeIntervalSince(windowStart) >= 3600 { windowStart = Date(); usedThisHour = 0 }
        usedThisHour += 1
    }

    public static func pickAction(mood: Mood) -> String {
        switch mood {
        case .happy: return ["蹭蹭你～", "看看我看看我！", "嘿嘿，在干嘛呀？", "戳戳～"].randomElement()!
        case .sleepy, .sleeping: return ["唔…你还醒着吗…", "眼皮好重…", "（揉眼睛）"].randomElement()!
        case .missing: return ["你在哪呀…", "我想你了…", "（探头看看你）"].randomElement()!
        case .calm: return ["（悄悄靠近你）", "（歪头看你）", "嗯…"].randomElement()!
        }
    }

    public static func pickEmote(mood: Mood) -> String {
        switch mood {
        case .happy: return "happy"
        case .sleepy: return "sleepy"
        case .sleeping: return "sleeping"
        case .missing: return "missyou"
        case .calm: return "idle"
        }
    }
}
