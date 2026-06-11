import Foundation

public enum MemorySearch {
    public static func search(query: String, in memories: [Memory], limit: Int = 5, now: Date = Date()) -> [Memory] {
        let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))
        let scored = memories.map { memory -> (Memory, Double) in
            var score = 0.0
            let contentWords = Set(memory.content.lowercased().split(separator: " ").map(String.init))
            let tagWords = Set(memory.tags.map { $0.lowercased() })
            let keywordHits = queryWords.intersection(contentWords.union(tagWords)).count
            score += Double(keywordHits) * 3.0
            if let lastAccess = memory.lastAccessedAt {
                let daysSince = now.timeIntervalSince(lastAccess) / 86400
                score += max(0, 2.0 - daysSince * 0.3)
            }
            score += Double(memory.importance) * 0.5
            score *= memory.confidence
            return (memory, score)
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }
}
