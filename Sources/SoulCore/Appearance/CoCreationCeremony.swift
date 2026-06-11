import Foundation

public enum CoCreationCeremony {
    public struct CeremonyPrompt: Sendable {
        public let announcement: String
        public let question: String
    }

    public static func evolutionAnnouncement(from: Stage, to: Stage, name: String) -> CeremonyPrompt {
        let fromCN = stageCN(from); let toCN = stageCN(to)
        return CeremonyPrompt(
            announcement: "\(name)感觉到身体在发生变化…它要从\(fromCN)变成\(toCN)了！",
            question: "请描述一下你想象中它蜕变后的样子（或输入「随机」让我来挑选）："
        )
    }

    public static func generateCandidates(from current: AppearanceGenome, count: Int = 3) -> [AppearanceGenome] {
        (0..<count).map { _ in
            var c = current
            switch Int.random(in: 0...3) {
            case 0: c.furHue = (c.furHue + Int.random(in: -30...30) + 360) % 360
            case 1: c.earShape = AppearanceGenome.EarShape.allCases.randomElement()!
            case 2: c.eyeStyle = AppearanceGenome.EyeStyle.allCases.randomElement()!
            case 3: c.tailType = AppearanceGenome.TailType.allCases.randomElement()!
            default: break
            }
            return c
        }
    }

    static func stageCN(_ s: Stage) -> String {
        switch s { case .egg: return "蛋"; case .baby: return "幼崽"; case .juvenile: return "少年"; case .adult: return "成年" }
    }
}
