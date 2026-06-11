import Foundation

public struct PersonalityTraits: Codable, Equatable, Sendable {
    public var curiosity: Double = 0.5
    public var talkativeness: Double = 0.5
    public var gentleness: Double = 0.5
    public var playfulness: Double = 0.5
    public var nightOwl: Double = 0.5

    public static let `default` = PersonalityTraits()
}

public enum PersonalityDrift {
    public struct DayInteractions: Sendable {
        public var chatCount: Int = 0
        public var attentionResponses: Int = 0
        public var lateNightActivity: Bool = false
        public var newTopicsExplored: Int = 0
        public var playCount: Int = 0

        public init(chatCount: Int = 0, attentionResponses: Int = 0, lateNightActivity: Bool = false, newTopicsExplored: Int = 0, playCount: Int = 0) {
            self.chatCount = chatCount
            self.attentionResponses = attentionResponses
            self.lateNightActivity = lateNightActivity
            self.newTopicsExplored = newTopicsExplored
            self.playCount = playCount
        }
    }

    public static func drift(traits: PersonalityTraits, interactions: DayInteractions) -> PersonalityTraits {
        var t = traits
        if interactions.chatCount > 5 {
            t.talkativeness = min(1.0, t.talkativeness + 0.02)
        }
        if interactions.chatCount < 2 {
            t.talkativeness = max(0.0, t.talkativeness - 0.01)
        }
        if interactions.attentionResponses > 0 {
            t.gentleness = min(1.0, t.gentleness + 0.03)
        }
        if interactions.lateNightActivity {
            t.nightOwl = min(1.0, t.nightOwl + 0.05)
        }
        if !interactions.lateNightActivity && t.nightOwl > 0.3 {
            t.nightOwl = max(0.0, t.nightOwl - 0.01)
        }
        if interactions.newTopicsExplored > 0 {
            t.curiosity = min(1.0, t.curiosity + 0.02)
        }
        if interactions.playCount > 3 {
            t.playfulness = min(1.0, t.playfulness + 0.03)
        }
        return t
    }

    public static func describe(_ traits: PersonalityTraits) -> String {
        var parts: [String] = []
        if traits.curiosity > 0.7 { parts.append("好奇心旺盛") }
        if traits.talkativeness > 0.7 {
            parts.append("话有点多")
        } else if traits.talkativeness < 0.3 {
            parts.append("沉默寡言")
        }
        if traits.gentleness > 0.7 { parts.append("很温柔") }
        if traits.nightOwl > 0.7 { parts.append("夜猫子") }
        if traits.playfulness > 0.7 { parts.append("很顽皮") }
        return parts.isEmpty ? "性格平和" : parts.joined(separator: "、")
    }
}
