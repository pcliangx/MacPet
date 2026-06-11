// Sources/SoulCore/Reflex/Mood.swift
import Foundation

public enum Mood: String, Codable, Sendable { case calm, happy, sleepy, missing, sleeping }

public struct MoodInputs: Sendable {
    public let attention: Attention
    public let hour: Int
    public let secondsSinceInteraction: TimeInterval
    public let phase: LifecyclePhase?
    public init(attention: Attention, hour: Int, secondsSinceInteraction: TimeInterval, phase: LifecyclePhase? = nil) {
        self.attention = attention; self.hour = hour
        self.secondsSinceInteraction = secondsSinceInteraction; self.phase = phase
    }
}

/// v0 优先序：想你 > 困 > 开心 > 平静。M2 增加 sleeping（asleep 阶段专用）。
public enum MoodEngine {
    /// V1（M0 接口，保持兼容）
    public static func mood(_ i: MoodInputs, nightHours: Set<Int> = [23, 0, 1, 2, 3, 4, 5]) -> Mood {
        if i.attention == .away && i.secondsSinceInteraction >= 2 * 3600 { return .missing }
        if nightHours.contains(i.hour) { return .sleepy }
        if i.secondsSinceInteraction <= 10 * 60 { return .happy }
        return .calm
    }
    /// V2（M2：集成 LifecyclePhase）
    public static func moodV2(_ i: MoodInputs, nightHours: Set<Int> = [23, 0, 1, 2, 3, 4, 5]) -> Mood {
        if let phase = i.phase {
            if phase == .asleep { return .sleeping }
            if phase == .drowsy { return .sleepy }
        }
        return mood(i, nightHours: nightHours)
    }
}
