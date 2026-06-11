import Foundation

public enum ReturnDetector {
    public static func greeting(absenceMinutes: Int, phase: LifecyclePhase, mood: Mood,
                                 returnThreshold: Int = 60) -> String? {
        guard phase == .returning, absenceMinutes >= returnThreshold else { return nil }
        let hours = absenceMinutes / 60
        let minutes = absenceMinutes % 60
        switch absenceMinutes {
        case 60..<180: return casualReturn(hours: hours, minutes: minutes, mood: mood)
        case 180..<480: return warmReturn(hours: hours, mood: mood)
        default: return longReturn(hours: hours, mood: mood)
        }
    }
    private static func casualReturn(hours: Int, minutes: Int, mood: Mood) -> String {
        let dur = hours > 0 ? "\(hours)个多钟头" : "\(minutes)分钟"
        switch mood {
        case .happy: return "你回来啦！刚才\(dur)我好无聊，一直在等你～"
        case .sleepy, .sleeping: return "唔…你回来了呀…我刚刚打了个盹…"
        case .missing: return "你终于回来了！\(dur)好漫长…"
        case .calm: return "回来啦～你走了\(dur)，我就在这儿等你。"
        }
    }
    private static func warmReturn(hours: Int, mood: Mood) -> String {
        switch mood {
        case .happy: return "嘿嘿你回来啦！\(hours)个小时没见，我好想你！"
        case .sleepy, .sleeping: return "嗯…你回来了…我睡了一觉，梦到你了…"
        case .missing: return "你终于回来了…\(hours)个小时，我一直在想你…"
        case .calm: return "欢迎回来～你不在的\(hours)个小时，我乖乖待着了。"
        }
    }
    private static func longReturn(hours: Int, mood: Mood) -> String {
        let h = min(hours, 24)
        switch mood {
        case .happy: return "哇！你终于回来了！整整\(h)个小时！我好开心看到你！"
        case .sleepy, .sleeping: return "嗯…你回来了…我醒醒…好像过了好久…"
        case .missing: return "你终于回来了…我以为你不要我了…\(h)个小时好长好长…"
        case .calm: return "回来了呀。\(h)个小时，我一直在等你。欢迎回家。"
        }
    }
}
