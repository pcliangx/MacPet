// Sources/SoulCore/Reflex/ReflexArc.swift
import Foundation

public enum ReactionIntensity: Int, Codable, Sendable, Comparable {
    case silent = 0, animate = 1, sound = 2, notify = 3
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// 旧设想中 Orchestrator 的通用化：任何来源的事件按 注意力×优先级 享受同一套喊人梯度（spec §5.2）
public enum ReflexArc {
    public static func intensity(attention: Attention, priority: PerceptPriority) -> ReactionIntensity {
        switch (priority, attention) {
        case (.alert, .attending): return .animate
        case (.alert, .elsewhere): return .sound
        case (.alert, .away):      return .notify
        case (.nudge, .attending): return .silent
        case (.nudge, _):          return .animate
        case (.ambient, _):        return .silent
        }
    }

    /// 零成本即时身体指令（不经 LLM）。强度逐级叠加：emote → +sound → +notify。
    public static func directives(for p: Percept, attention: Attention, mood: Mood) -> [PeripheralMessage] {
        let level = intensity(attention: attention, priority: p.priority)
        guard level > .silent else { return [] }
        var out: [PeripheralMessage] = [
            .directive(kind: "emote", payload: ["animation": .string("alert"), "mood": .string(mood.rawValue)])
        ]
        if level >= .sound {
            out.append(.directive(kind: "sound", payload: ["name": .string("chirp")]))
        }
        if level >= .notify {
            let title = p.payload["title"]?.stringValue ?? p.kind
            out.append(.directive(kind: "notify", payload: [
                "title": .string(title),
                "perceptId": .string(p.id),
                "actions": .array(p.actions.map { .object(["id": .string($0.id), "label": .string($0.label)]) }),
            ]))
        }
        return out
    }
}
