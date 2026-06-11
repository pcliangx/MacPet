import Foundation

/// M9 礼物仪式（spec §10.7）：装插件 = 送它一个礼物。
public enum GiftCeremony {
    public struct Ceremony: Sendable {
        public let unwrapLine: String       // 拆礼物台词
        public let toyNickname: String      // 它给玩具起的昵称
        public let tryOutLine: String       // 试用台词
        public let diaryNote: String        // 当晚日记素材
    }

    /// 生成拆礼物仪式（按 manifest persona_hints）
    public static func perform(manifest: PluginManifest, petName: String) -> Ceremony {
        let toyName = manifest.personaHints?.toyName ?? manifest.displayName
        let intro = manifest.personaHints?.intro ?? "一个新玩具"
        return Ceremony(
            unwrapLine: "哇！是给我的礼物吗？我拆开看看……是「\(toyName)」！",
            toyNickname: toyName,
            tryOutLine: "让我试试……\(intro)！太好玩了！",
            diaryNote: "今天主人送了我一个礼物：「\(toyName)」。\(intro)。我会好好用它的！"
        )
    }

    /// 卸载 = 收起玩具（不悲情）
    public static func putAway(toyName: String) -> String {
        "好吧，把「\(toyName)」收起来啦。改天再玩～"
    }
}
