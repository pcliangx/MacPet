import Foundation

public enum MemoryKind: String, Codable, Sendable { case episodic, semantic, milestone }

public struct Memory: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var kind: MemoryKind
    public var content: String
    public var source: String?
    public var confidence: Double
    public var importance: Int
    public var createdAt: Date
    public var lastAccessedAt: Date?
    public var accessCount: Int = 0
    public var tags: [String] = []

    public init(id: String = UUID().uuidString, kind: MemoryKind, content: String,
                source: String? = nil, confidence: Double = 0.8, importance: Int = 3,
                createdAt: Date = Date(), tags: [String] = []) {
        self.id = id; self.kind = kind; self.content = content
        self.source = source; self.confidence = confidence
        self.importance = importance; self.createdAt = createdAt; self.tags = tags
    }
}
