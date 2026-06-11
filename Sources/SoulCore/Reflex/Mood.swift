// Sources/SoulCore/Reflex/Mood.swift
import Foundation

public enum Mood: String, Codable, Sendable { case calm, happy, sleepy, missing }

public struct MoodInputs: Sendable {
    public let attention: Attention
    public let hour: Int                      // 0-23，本地时
    public let secondsSinceInteraction: TimeInterval
    public init(attention: Attention, hour: Int, secondsSinceInteraction: TimeInterval) {
        self.attention = attention; self.hour = hour
        self.secondsSinceInteraction = secondsSinceInteraction
    }
}

/// v0 优先序：想你 > 困 > 开心 > 平静。夜窗固定 23-5 点（M3 作息自适应后改为学习值）。
public enum MoodEngine {
    public static func mood(_ i: MoodInputs, nightHours: Set<Int> = [23, 0, 1, 2, 3, 4, 5]) -> Mood {
        if i.attention == .away && i.secondsSinceInteraction >= 2 * 3600 { return .missing }
        if nightHours.contains(i.hour) { return .sleepy }
        if i.secondsSinceInteraction <= 10 * 60 { return .happy }
        return .calm
    }
}
