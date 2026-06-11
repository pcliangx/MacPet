// Sources/SoulCore/Reflex/Attention.swift
import Foundation

public enum Attention: String, Codable, Sendable { case attending, elsewhere, away }

public struct PresenceSnapshot: Equatable, Sendable {
    public let frontmostBundleID: String?
    public let idleSeconds: TimeInterval
    public let watchedBundleIDs: Set<String>
    public init(frontmostBundleID: String?, idleSeconds: TimeInterval, watchedBundleIDs: Set<String>) {
        self.frontmostBundleID = frontmostBundleID
        self.idleSeconds = idleSeconds
        self.watchedBundleIDs = watchedBundleIDs
    }
}

public enum AttentionResolver {
    public static func resolve(_ s: PresenceSnapshot, awayThreshold: TimeInterval = 180) -> Attention {
        if s.idleSeconds >= awayThreshold { return .away }
        if let f = s.frontmostBundleID, s.watchedBundleIDs.contains(f) { return .attending }
        return .elsewhere
    }
}
