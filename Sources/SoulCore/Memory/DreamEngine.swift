import Foundation

public enum DreamEngine {
    public static func distill(episodic: [Memory]) -> [Memory] {
        var semanticMemories: [Memory] = []
        let grouped = Dictionary(grouping: episodic, by: { extractTopic($0.content) })
        for (topic, events) in grouped where events.count >= 2 {
            let semantic = Memory(
                kind: .semantic, content: "主人似乎\(topic)",
                confidence: min(0.95, Double(events.count) * 0.15 + 0.3),
                importance: min(5, events.count), tags: [topic]
            )
            semanticMemories.append(semantic)
        }
        return semanticMemories
    }

    static func extractTopic(_ content: String) -> String {
        String(content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(10))
    }

    public static func checkMilestones(growthState: GrowthState) -> [Memory] {
        var milestones: [Memory] = []
        if growthState.stage == .juvenile && growthState.totalXP >= 500 && growthState.totalXP < 550 {
            milestones.append(Memory(kind: .milestone, content: "长大成少年了！", importance: 5))
        }
        if growthState.streakDays == 7 {
            milestones.append(Memory(kind: .milestone, content: "连续陪伴 7 天", importance: 4))
        }
        if growthState.streakDays == 30 {
            milestones.append(Memory(kind: .milestone, content: "连续陪伴 30 天", importance: 5))
        }
        return milestones
    }
}
