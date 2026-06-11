import Foundation

/// M2 待机小动作（spec §5.2）
public enum IdleActions {
    public static func pick(phase: LifecyclePhase, mood: Mood) -> (String, String?) {
        switch phase {
        case .asleep: return ("sleeping", sleepTalk())
        case .drowsy: return (mood == .sleepy ? "sleepy" : "idle", drowsyTalk())
        case .active: return (activeEmote(mood: mood), activeTalk(mood: mood))
        case .returning: return ("idle", nil)
        }
    }
    private static func activeEmote(mood: Mood) -> String {
        switch mood {
        case .happy: return Bool.random() ? "happy" : "idle"
        default: return "idle"
        }
    }
    private static func activeTalk(mood: Mood) -> String? {
        guard Int.random(in: 0..<10) < 3 else { return nil }
        switch mood {
        case .happy: return ["今天天气好像不错～", "嘿嘿", "在想什么呢"].randomElement()
        case .calm: return ["…", "嗯", "（发呆）"].randomElement()
        case .sleepy, .sleeping: return ["好困…", "（打了个哈欠）"].randomElement()
        case .missing: return ["你在忙什么呀…", "（叹气）"].randomElement()
        }
    }
    private static func drowsyTalk() -> String? {
        guard Int.random(in: 0..<10) < 4 else { return nil }
        return ["唔…", "眼皮好重…", "（揉眼睛）", "该睡了吧…"].randomElement()
    }
    private static func sleepTalk() -> String? {
        guard Int.random(in: 0..<10) < 2 else { return nil }
        return ["zzz…", "…嗯…", "（翻身）"].randomElement()
    }
}
