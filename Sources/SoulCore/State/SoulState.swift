// Sources/SoulCore/State/SoulState.swift
import Foundation

public struct SoulState: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 1
    public var mood: Mood = .calm
    public var lastInteractionAt: Date? = nil
    public var queuedThoughts: [String] = []     // 「醒来要说的话」（spec §5.1 身体缺席降级）
    public init() {}
}
